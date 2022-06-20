// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

contract AnimaVerseMintGame is Ownable, ERC721 {
    using Strings for uint256;

    string private baseURI;
    bytes32 public gamesMerkleRoot;
    mapping(uint256 => uint256) public scores;

    constructor(string memory collectionURI) ERC721('AnimaVerse Mint Game', 'AVMG') {
        baseURI = collectionURI;
    }

    function submitGameScore(
        uint256 gameIndex,
        uint256 score,
        uint256 sr,
        bytes32[] calldata proof
    ) public {
        bytes32 leaf = keccak256(abi.encodePacked(gameIndex, score, sr));
        require(MerkleProof.verify(proof, gamesMerkleRoot, leaf), 'AVMG: Invalid proof');

        scores[gameIndex] = score;
        _safeMint(_msgSender(), gameIndex);
    }

    function setGamesRoot(bytes32 merkleRoot) public onlyOwner {
        gamesMerkleRoot = merkleRoot;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(from == address(0), 'AVMG: Transfer is not allowed');
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
