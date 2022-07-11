// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import 'erc721a/contracts/ERC721A.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract AnimaVerseCollection is Ownable, ERC721A, IERC2981, ReentrancyGuard {
    uint16 private constant BASE = 10000;
    uint16 private constant MAX_TOKENS = 10004;

    string private baseURI;
    string private _contractMetadata;

    uint16 private _royalty = 1000; // base 10000, 5%
    uint16 private _communityRoyaltyShare = 9850; // base 10000, 98.5%
    uint16 private _roundLastToken = 2501;
    uint16 private _maxAddressMint = 1;
    uint16 private _maxAddressRoundMint = 1;
    uint256 private _mintPrice;

    address private _artistsWithdrawAccount;
    address private _communityWithdrawAccount;

    mapping(address => uint16) private _lastAddressMintRound;
    mapping(address => uint16) private _mintedCount;

    error NotExists();
    error AlreadySet();
    error NoTokensLeft();
    error Unauthorized();
    error NotEnoughETH();
    error WithdrawFailed();
    error BadRoyaltyInput();
    error InsufficientFunds();
    error AlreadyMintedRound();
    error BadMaxAddressMintInput();
    error BadRoundLastTokenInput();

    constructor(string memory contractMetadata, string memory collectionURI) ERC721A('AnimaVerse Collection', 'AVC') {
        _contractMetadata = contractMetadata;
        baseURI = collectionURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function contractURI() public view returns (string memory) {
        return _contractMetadata;
    }

    function mintPrice() public view returns (uint256) {
        return _mintPrice;
    }

    function roundLastToken() public view returns (uint16) {
        return _roundLastToken;
    }

    function maxAddressMint() public view returns (uint16) {
        return _maxAddressMint;
    }

    function maxAddressRoundMint() public view returns (uint16) {
        return _maxAddressRoundMint;
    }

    function mintedCount(address account) public view returns (uint16) {
        return _mintedCount[account];
    }

    function lastAddressMintRound(address account) public view returns (uint16) {
        return _lastAddressMintRound[account];
    }

    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (address(this), (salePrice * _royalty) / BASE);
    }

    function mint(uint16 quantity) public payable {
        address msgSender = _msgSender();
        uint256 currentSupply = _nextTokenId();
        uint16 roundLastToken = _roundLastToken;
        uint256 newSupply;
        uint16 newAddressMintedCount;
        uint256 totalPrice;
        unchecked {
            newSupply = currentSupply + quantity;
            newAddressMintedCount = _mintedCount[msgSender] + quantity;
            totalPrice = quantity * _mintPrice;
        }

        if (msgSender != tx.origin) revert Unauthorized();
        if (newSupply > roundLastToken) revert NoTokensLeft();
        if (quantity > _maxAddressRoundMint) revert NoTokensLeft();
        if (newAddressMintedCount > _maxAddressMint) revert NoTokensLeft();
        if (_lastAddressMintRound[msgSender] == roundLastToken) revert AlreadyMintedRound();
        if (msg.value < totalPrice) {
            revert NoTokensLeft();
        } else if (msg.value > totalPrice) {
            payable(msgSender).transfer(msg.value - totalPrice);
        }

        _lastAddressMintRound[msgSender] = roundLastToken;
        _mintedCount[msgSender] = newAddressMintedCount;
        _mint(msgSender, quantity);
    }

    function setContractMetadata(string calldata contractMetadata) public onlyOwner {
        _contractMetadata = contractMetadata;
    }

    function setNewRound(
        uint256 price,
        uint16 roundLastToken,
        uint16 maxAddressMint,
        uint16 maxAddressRoundMint
    ) public onlyOwner {
        if (roundLastToken > MAX_TOKENS) revert BadRoundLastTokenInput();
        if (roundLastToken < _roundLastToken) revert BadRoundLastTokenInput();
        if (maxAddressMint < _maxAddressMint) revert BadMaxAddressMintInput();

        _mintPrice = price;
        _roundLastToken = roundLastToken;
        _maxAddressMint = maxAddressMint;
        _maxAddressRoundMint = maxAddressRoundMint;
    }

    function setBaseURI(string calldata collectionURI) public onlyOwner {
        baseURI = collectionURI;
    }

    function setRoyalty(uint16 royalty) public onlyOwner {
        if (royalty > 1000) {
            revert BadRoyaltyInput();
        }
        _royalty = royalty;
    }

    function setCommunityRoyaltyShare(uint16 communityRoyaltyShare) public onlyOwner {
        if (communityRoyaltyShare > 1000) {
            revert BadRoyaltyInput();
        }
        _communityRoyaltyShare = communityRoyaltyShare;
    }

    function setCommunityWithdrawMainAccount(address account) public onlyOwner {
        if (_communityWithdrawAccount == account) {
            revert AlreadySet();
        }
        _communityWithdrawAccount = account;
    }

    function setArtistsWithdrawAccount(address account) public onlyOwner {
        if (_artistsWithdrawAccount == account) {
            revert AlreadySet();
        }
        _artistsWithdrawAccount = account;
    }

    function withdraw(uint256 _amount) public onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (_amount > balance) {
            revert InsufficientFunds();
        }

        uint256 cShare;
        uint256 aShare;
        unchecked {
            cShare = (_amount * _communityRoyaltyShare) / BASE;
            aShare = _amount - cShare;
        }

        bool communityWithdrawResult;
        (communityWithdrawResult, ) = payable(_communityWithdrawAccount).call{value: cShare}('');
        if (!communityWithdrawResult) {
            revert WithdrawFailed();
        }

        bool artistsWithdrawResult;
        (artistsWithdrawResult, ) = payable(_artistsWithdrawAccount).call{value: aShare}('');
        if (!artistsWithdrawResult) {
            revert WithdrawFailed();
        }

        emit ContractWithdraw(_communityWithdrawAccount, cShare);
        emit ContractWithdraw(_artistsWithdrawAccount, aShare);
    }

    function withdrawTokens(address _tokenContract, uint256 _amount) public onlyOwner nonReentrant {
        IERC20 tokenContract = IERC20(_tokenContract);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (_amount > balance) {
            revert InsufficientFunds();
        }

        uint256 cShare;
        uint256 aShare;
        unchecked {
            cShare = (_amount * _communityRoyaltyShare) / BASE;
            aShare = _amount - cShare;
        }

        tokenContract.transfer(_communityWithdrawAccount, cShare);
        tokenContract.transfer(_artistsWithdrawAccount, aShare);

        emit ContractWithdrawToken(_communityWithdrawAccount, _tokenContract, cShare);
        emit ContractWithdrawToken(_artistsWithdrawAccount, _tokenContract, aShare);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    event ContractWithdraw(address indexed withdrawAddress, uint256 amount);
    event ContractWithdrawToken(address indexed withdrawAddress, address indexed token, uint256 amount);
}
