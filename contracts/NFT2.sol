// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

error NotExists();
error AlreadySet();
error NoTokensLeft();
error NotEnoughETH();
error WithdrawFailed();
error BadRoyaltyInput();
error InsufficientFunds();
error AlreadyMintedRound();
error BadMaxAddressMintInput();
error BadRoundLastTokenInput();

contract AnimaVerseCollectionTest is Ownable, ERC721, IERC2981 {
    using Strings for uint256;

    uint16 private constant BASE = 10000;
    uint16 private constant MAX_TOKENS = 10004;
    uint16 private _totalSupply;

    string private baseURI;
    string private contractMetadata;

    uint16 public royalty = 1000; // base 10000, 5%
    uint16 public commiunityRoyaltyShare = 9850; // base 10000, 98.5%
    uint16 public roundLastToken = 2501;
    uint16 public maxAddressMint = 1;
    uint16 public maxAddressRoundMint = 1;
    uint256 public mintPrice;

    address public artistsWithdrawAccount;
    address public commiunityWithdrawAccount;

    mapping(address => uint16) public lastAddressMintRound;
    mapping(address => uint16) public mintedCount;

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
        uint16 newSupply;
        uint16 newAddressMintedCount;
        uint256 totalPrice;
        unchecked {
            newSupply = _totalSupply + quantity;
            newAddressMintedCount = mintedCount[msgSender] + quantity;
        }

        if (newSupply > roundLastToken) revert NoTokensLeft();
        if (newAddressMintedCount > maxAddressMint) revert NoTokensLeft();
        if (quantity > maxAddressRoundMint) revert NoTokensLeft();
        if (lastAddressMintRound[msgSender] == roundLastToken) revert AlreadyMintedRound();

        if (mintPrice > 0) {
            unchecked {
                totalPrice = quantity * mintPrice;
            }
        }
        if (msg.value < totalPrice) {
            revert NoTokensLeft();
        } else if (msg.value > totalPrice) {
            payable(msgSender).transfer(msg.value - totalPrice);
        }

        lastAddressMintRound[msgSender] = roundLastToken;
        mintedCount[msgSender] = newAddressMintedCount;
        while (_totalSupply < newSupply) {
            _safeMint(msgSender, _totalSupply);
            unchecked {
                ++_totalSupply;
            }
        }
    }

    function setContractMetadata(string memory _contractMetadata) public onlyOwner {
        contractMetadata = _contractMetadata;
    }

    function setBaseURI(string memory collectionURI) public onlyOwner {
        baseURI = collectionURI;
    }

    function setRoundAvailableTokens(
        uint16 _maxAddressMint,
        uint16 _maxAddressRoundMint,
        uint16 _roundLastToken,
        uint256 price
    ) public onlyOwner {
        if (_roundLastToken > MAX_TOKENS) revert BadRoundLastTokenInput();
        if (_roundLastToken < roundLastToken) revert BadRoundLastTokenInput();
        if (_maxAddressMint < maxAddressMint) revert BadMaxAddressMintInput();

        mintPrice = price;
        roundLastToken = _roundLastToken;
        maxAddressMint = _maxAddressMint;
        maxAddressRoundMint = _maxAddressRoundMint;
    }

    function setRoyalty(uint16 _royalty) public onlyOwner {
        if (_royalty > 1000) {
            revert BadRoyaltyInput();
        }
        royalty = _royalty;
    }

    function setCommiunityRoyaltyShare(uint16 _commiunityRoyaltyShare) public onlyOwner {
        if (_commiunityRoyaltyShare > 1000) {
            revert BadRoyaltyInput();
        }
        commiunityRoyaltyShare = _commiunityRoyaltyShare;
    }

    function setCommiunityWithdrawMainAccount(address account) public onlyOwner {
        if (commiunityWithdrawAccount == account) {
            revert AlreadySet();
        }
        commiunityWithdrawAccount = account;
    }

    function setArtistsWithdrawAccount(address account) public onlyOwner {
        if (artistsWithdrawAccount == account) {
            revert AlreadySet();
        }
        artistsWithdrawAccount = account;
    }

    function withdraw(uint256 _amount) public onlyOwner {
        uint256 balance = address(this).balance;
        if (_amount > balance) {
            revert InsufficientFunds();
        }

        uint256 cShare;
        uint256 aShare;
        unchecked {
            cShare = (_amount * commiunityRoyaltyShare) / BASE;
            aShare = _amount - cShare;
        }

        bool commiunityWithdrawResult;
        (commiunityWithdrawResult, ) = payable(commiunityWithdrawAccount).call{value: cShare}('');
        if (!commiunityWithdrawResult) {
            revert WithdrawFailed();
        }

        bool artistsWithdrawResult;
        (artistsWithdrawResult, ) = payable(artistsWithdrawAccount).call{value: aShare}('');
        if (!artistsWithdrawResult) {
            revert WithdrawFailed();
        }

        emit ContractWithdraw(commiunityWithdrawAccount, cShare);
        emit ContractWithdraw(artistsWithdrawAccount, aShare);
    }

    function withdrawTokens(address _tokenContract, uint256 _amount) public onlyOwner {
        IERC20 tokenContract = IERC20(_tokenContract);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (_amount > balance) {
            revert InsufficientFunds();
        }

        uint256 cShare;
        uint256 aShare;
        unchecked {
            cShare = (_amount * commiunityRoyaltyShare) / BASE;
            aShare = _amount - cShare;
        }

        tokenContract.transfer(commiunityWithdrawAccount, cShare);
        tokenContract.transfer(artistsWithdrawAccount, aShare);

        emit ContractWithdrawToken(commiunityWithdrawAccount, _tokenContract, cShare);
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
