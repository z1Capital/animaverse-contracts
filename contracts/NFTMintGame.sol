// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

contract AnimaVerseCollectionWithGame is Ownable, ERC721, IERC2981 {
    using Strings for uint256;

    uint16 internal royalty = 500; // base 10000, 5%
    uint16 public constant BASE = 10000;
    uint16 public constant FREE_TOKENS = 5000;
    uint16 public constant MAX_TOKENS = 10000;
    uint16 public constant MAX_MINT = 3;
    uint256 public constant MINT_PRICE = 0.1 ether;
    uint256 public publicMintingStartBlock = type(uint256).max - 1;
    uint256 public totalSupply;

    bool public whitelistMinting = true;
    bool public gameWinnersMinting;

    string private baseURI;
    string private contractMetadata;

    address public withdrawAccount;
    ERC721 public mintGameContract;
    bytes32 public whitelistMerkleRoot;

    mapping(uint256 => bool) public mintedGameIds;
    mapping(address => uint16) public mintedCount;

    modifier onlyWhitdrawable() {
        require(_msgSender() == withdrawAccount, 'AVC: Not authorzed to withdraw');
        _;
    }

    modifier paid(uint16 quantity) {
        uint256 totalPrice;
        if (totalSupply >= FREE_TOKENS) {
            totalPrice = quantity * MINT_PRICE;
        }
        require(msg.value >= totalPrice, 'AVC: Not enough ethers');
        if (msg.value > totalPrice) {
            payable(_msgSender()).transfer(msg.value - totalPrice);
        }
        _;
    }

    constructor(string memory _contractMetadata, string memory collectionURI) ERC721('AnimaVerse Collection', 'AVC') {
        contractMetadata = _contractMetadata;
        baseURI = collectionURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'AVC: URI query for nonexistent token');
        string memory baseContractURI = _baseURI();
        return string(abi.encodePacked(baseContractURI, tokenId.toString()));
    }

    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (address(this), (_salePrice * royalty) / BASE);
    }

    function whitelistMint(uint16 quantity, bytes32[] calldata proof) public payable paid(quantity) {
        require(whitelistMinting, 'AVC: Whitelist Minting is not allowed');
        require(totalSupply + quantity <= MAX_TOKENS, 'AVC: That many tokens are not available');
        address msgSender = _msgSender();

        uint16 accountNewMintCount = mintedCount[msgSender] + quantity;
        require(accountNewMintCount <= MAX_MINT, 'AVC: That many tokens are not available');

        bytes32 leaf = keccak256(abi.encodePacked(msgSender));
        require(MerkleProof.verify(proof, whitelistMerkleRoot, leaf), 'AVC: Invalid proof');

        mintedCount[msgSender] = accountNewMintCount;
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msgSender, ++totalSupply);
        }
    }

    function gameWinnersMint(uint256 gameId) public payable paid(1) {
        require(gameWinnersMinting, 'AVC: Game winners minting is not allowed at this time');
        require(totalSupply < MAX_TOKENS, 'AVC: That many tokens are not available');
        address msgSender = _msgSender();

        uint16 accountNewMintCount = mintedCount[msgSender] + 1;
        require(accountNewMintCount <= MAX_MINT, 'AVC: That many tokens are not available');

        require(!mintedGameIds[gameId], 'AVC: Game already minted');
        address tokenIDOwner = mintGameContract.ownerOf(gameId);
        require(msgSender == tokenIDOwner, 'AVC: Not winner of game');

        mintedGameIds[gameId] = true;
        mintedCount[msgSender] = accountNewMintCount;
        _safeMint(msgSender, ++totalSupply);
    }

    function mint(uint16 quantity) public payable paid(quantity) {
        require(publicMintingStartBlock <= block.number, 'AVC: Minting time is not started');
        require(totalSupply + quantity <= MAX_TOKENS, 'AVC: That many tokens are not available');
        address msgSender = _msgSender();

        uint16 accountNewMintCount = mintedCount[msgSender] + quantity;
        require(accountNewMintCount <= MAX_MINT, 'AVC: That many tokens are not available this account');

        mintedCount[msgSender] = accountNewMintCount;
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msgSender, ++totalSupply);
        }
    }

    function setWhitelistMerkleRoot(bytes32 merkleRoot) public onlyOwner {
        whitelistMerkleRoot = merkleRoot;
    }

    function setContractMetadata(string memory _contractMetadata) public onlyOwner {
        contractMetadata = _contractMetadata;
    }

    function setBaseURI(string memory collectionURI) public onlyOwner {
        baseURI = collectionURI;
    }

    function setPublicMintingStartBlock(uint256 _block) public onlyOwner {
        publicMintingStartBlock = _block;
        emit StartTimeUpdated(_block);
    }

    function setRoyalty(uint16 _royalty) public onlyOwner {
        require(_royalty >= 0 && _royalty <= 1000, 'AVC: Royalty must be between 0% and 10%');
        royalty = _royalty;
    }

    function setWhitelistMinting(bool isActive) public onlyOwner {
        require(isActive != whitelistMinting, 'AVC: Whitelist minting is already set to this value');
        whitelistMinting = isActive;
        emit WhitelistMintingStatusUpdated(isActive);
    }

    function setGameWinnersMinting(bool isActive) public onlyOwner {
        require(isActive != gameWinnersMinting, 'AVC: Whitelist minting is already set to this value');
        gameWinnersMinting = isActive;
        emit GameWinnersMintingStatusUpdated(isActive);
    }

    function setWithdrawAccount(address account) public onlyOwner {
        require(withdrawAccount != account, 'AVC: Already set');
        withdrawAccount = account;
    }

    function setMintGameContract(address _mintGameContract) public onlyOwner {
        require(address(mintGameContract) != _mintGameContract, 'AVC: Already set');
        mintGameContract = ERC721(_mintGameContract);
    }

    function withdraw(uint256 _amount) public onlyWhitdrawable {
        uint256 balance = address(this).balance;
        require(_amount <= balance, 'AVC: Insufficient funds');
        address msgSender = _msgSender();

        bool success;
        (success, ) = payable(msgSender).call{value: _amount}('');
        require(success, 'AVC: Withdraw failed');

        emit ContractWithdraw(msgSender, _amount);
    }

    function withdrawTokens(address _tokenContract, uint256 _amount) public onlyWhitdrawable {
        IERC20 tokenContract = IERC20(_tokenContract);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance >= _amount, 'AVC: Not enough balance');
        address msgSender = _msgSender();

        tokenContract.transfer(msgSender, _amount);

        emit ContractWithdrawToken(msgSender, _tokenContract, _amount);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _exists(uint256 tokenId) internal view override returns (bool) {
        return tokenId < totalSupply;
    }

    event ContractWithdraw(address indexed withdrawAddress, uint256 amount);
    event ContractWithdrawToken(address indexed withdrawAddress, address indexed token, uint256 amount);
    event WhitelistAdded(uint256 index, bytes32 merkleRoot, uint256 quantity, uint256 price);
    event WhitelistUpdated(uint256 index, bytes32 merkleRoot);
    event StartTimeUpdated(uint256 blockNumber);
    event WhitelistMintingStatusUpdated(bool isActive);
    event GameWinnersMintingStatusUpdated(bool isActive);
}
