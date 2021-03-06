// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AnimaVerseCollectionTest is Ownable, ERC721, IERC2981, ReentrancyGuard {
    using Strings for uint256;

    uint16 private constant BASE = 10000;
    uint16 private constant MAX_TOKENS = 10004;
    uint16 private _totalSupply;

    string private baseURI;
    string private contractMetadata;

    uint16 public royalty = 1000; // base 10000, 5%
    uint16 public communityRoyaltyShare = 9850; // base 10000, 98.5%
    uint16 public roundLastToken = 2501;
    uint16 public maxAddressMint = 1;
    uint16 public maxAddressRoundMint = 1;
    uint256 public mintPrice;

    address public artistsWithdrawAccount;
    address public communityWithdrawAccount;

    mapping(address => uint16) public lastAddressMintRound;
    mapping(address => uint16) public mintedCount;

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

    constructor(string memory _contractMetadata, string memory collectionURI) ERC721('AnimaVerse Collection', 'AVC') {
        contractMetadata = _contractMetadata;
        baseURI = collectionURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert NotExists();
        }
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (address(this), (_salePrice * royalty) / BASE);
    }

    function mint(uint16 quantity) public payable {
        address msgSender = _msgSender();
        uint16 currentSupply = _totalSupply;
        uint16 newSupply;
        uint16 newAddressMintedCount;
        uint256 totalPrice;
        unchecked {
            newSupply = currentSupply + quantity;
            newAddressMintedCount = mintedCount[msgSender] + quantity;
        }

        if (msgSender != tx.origin) revert Unauthorized();
        if (newSupply > roundLastToken) revert NoTokensLeft();
        if (quantity > maxAddressRoundMint) revert NoTokensLeft();
        if (newAddressMintedCount > maxAddressMint) revert NoTokensLeft();
        if (lastAddressMintRound[msgSender] == roundLastToken) revert AlreadyMintedRound();

        if (mintPrice > 0) {
            unchecked {
                totalPrice = quantity * mintPrice;
            }
        }
        if (msg.value < totalPrice) {
            revert NoTokensLeft();
        } else if (msg.value != totalPrice) {
            payable(msgSender).transfer(msg.value - totalPrice);
        }

        lastAddressMintRound[msgSender] = roundLastToken;
        mintedCount[msgSender] = newAddressMintedCount;
        while (currentSupply < newSupply) {
            _mint(msgSender, currentSupply);
            unchecked {
                ++currentSupply;
            }
        }
        _totalSupply = currentSupply;
    }

    function setContractMetadata(string calldata _contractMetadata) public onlyOwner {
        contractMetadata = _contractMetadata;
    }

    function setNewRound(
        uint256 _price,
        uint16 _roundLastToken,
        uint16 _maxAddressMint,
        uint16 _maxAddressRoundMint
    ) public onlyOwner {
        if (_roundLastToken > MAX_TOKENS) revert BadRoundLastTokenInput();
        if (_roundLastToken < roundLastToken) revert BadRoundLastTokenInput();
        if (_maxAddressMint < maxAddressMint) revert BadMaxAddressMintInput();

        mintPrice = _price;
        roundLastToken = _roundLastToken;
        maxAddressMint = _maxAddressMint;
        maxAddressRoundMint = _maxAddressRoundMint;
    }

    function setBaseURI(string calldata collectionURI) public onlyOwner {
        baseURI = collectionURI;
    }

    function setRoyalty(uint16 _royalty) public onlyOwner {
        if (_royalty > 1000) {
            revert BadRoyaltyInput();
        }
        royalty = _royalty;
    }

    function setCommunityRoyaltyShare(uint16 _communityRoyaltyShare) public onlyOwner {
        if (_communityRoyaltyShare > 1000) {
            revert BadRoyaltyInput();
        }
        communityRoyaltyShare = _communityRoyaltyShare;
    }

    function setCommunityWithdrawMainAccount(address account) public onlyOwner {
        if (communityWithdrawAccount == account) {
            revert AlreadySet();
        }
        communityWithdrawAccount = account;
    }

    function setArtistsWithdrawAccount(address account) public onlyOwner {
        if (artistsWithdrawAccount == account) {
            revert AlreadySet();
        }
        artistsWithdrawAccount = account;
    }

    function withdraw(uint256 _amount) public onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (_amount > balance) {
            revert InsufficientFunds();
        }

        uint256 cShare;
        uint256 aShare;
        unchecked {
            cShare = (_amount * communityRoyaltyShare) / BASE;
            aShare = _amount - cShare;
        }

        bool communityWithdrawResult;
        (communityWithdrawResult, ) = payable(communityWithdrawAccount).call{value: cShare}('');
        if (!communityWithdrawResult) {
            revert WithdrawFailed();
        }

        bool artistsWithdrawResult;
        (artistsWithdrawResult, ) = payable(artistsWithdrawAccount).call{value: aShare}('');
        if (!artistsWithdrawResult) {
            revert WithdrawFailed();
        }

        emit ContractWithdraw(communityWithdrawAccount, cShare);
        emit ContractWithdraw(artistsWithdrawAccount, aShare);
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
            cShare = (_amount * communityRoyaltyShare) / BASE;
            aShare = _amount - cShare;
        }

        tokenContract.transfer(communityWithdrawAccount, cShare);
        tokenContract.transfer(artistsWithdrawAccount, aShare);

        emit ContractWithdrawToken(communityWithdrawAccount, _tokenContract, cShare);
        emit ContractWithdrawToken(artistsWithdrawAccount, _tokenContract, aShare);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _exists(uint256 tokenId) internal view override returns (bool) {
        return tokenId < _totalSupply;
    }

    event ContractWithdraw(address indexed withdrawAddress, uint256 amount);
    event ContractWithdrawToken(address indexed withdrawAddress, address indexed token, uint256 amount);
}
