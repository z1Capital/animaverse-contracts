const keccak256 = require('keccak256')
const { expect } = require('chai')
const { MerkleTree } = require('merkletreejs')
const { generateGame, getLeaf } = require('./aux')

describe('NFT contract', function () {
  let AnimaVerseMintGameInstance
  let AnimaVerseCollectionInstance
  let owner
  let addr1
  let addr2
  let addrs

  const leafNodes = []
  const games = []
  for (let index = 0; index < 2; index++) {
    const game = generateGame()
    game.index = index
    games.push(game)
    leafNodes.push(getLeaf(game))
  }
  const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true })

  beforeEach(async function () {
    ;[owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    const AnimaVerseMintGame = await ethers.getContractFactory('AnimaVerseMintGame')
    AnimaVerseMintGameInstance = await AnimaVerseMintGame.deploy()
    await AnimaVerseMintGameInstance.setGamesRoot(merkleTree.getRoot())

    const AnimaVerseCollection = await ethers.getContractFactory('AnimaVerseCollection')
    AnimaVerseCollectionInstance = await AnimaVerseCollection.deploy('', '')
    await AnimaVerseCollectionInstance.setMintGameContract(AnimaVerseMintGameInstance.address)
  })

  // prevent double submit one id
  describe('Deployment', function () {
    it('Should set the right mint game contract address', async function () {
      expect(await AnimaVerseCollectionInstance.mintGameContract()).to.equal(AnimaVerseMintGameInstance.address)
    })
  })

  // Add wl
  // wl mint
  // winner mint
  // prevent double mint of winner
  // public mint
  // withdraw
  describe('NFT Mint', function () {
    it('whitelist mint', async function () {
      const wlMintCount = await AnimaVerseCollectionInstance.MAX_WL_MINT()
      const wlMintPrice = await AnimaVerseCollectionInstance.WL_MINT_PRICE()
      const whitelistLeafNodes = addrs.map((i) => keccak256(i.address))
      const minter = addrs[0]
      const whitelistMerkleTree = new MerkleTree(whitelistLeafNodes, keccak256, { sortPairs: true })

      const whitelistMerkleRoot = whitelistMerkleTree.getRoot()
      await AnimaVerseCollectionInstance.setWhitelistMerkleRoot(whitelistMerkleRoot)
      const proof = whitelistMerkleTree.getHexProof(keccak256(minter.address))
      await AnimaVerseCollectionInstance.connect(minter).whitelistMint(wlMintCount, proof, {
        value: wlMintPrice.mul(wlMintCount),
      })
      const balance = await AnimaVerseCollectionInstance.balanceOf(minter.address)
      expect(balance.toNumber()).to.equal(wlMintCount)
    })

    it('winners mint', async function () {
      const wlMintPrice = await AnimaVerseCollectionInstance.WL_MINT_PRICE()
      const gameIndex = 1
      const proof = merkleTree.getHexProof(getLeaf(games[gameIndex]))
      await AnimaVerseMintGameInstance.connect(addr1).submitGameScore(
        gameIndex,
        games[gameIndex].score,
        games[gameIndex].sr,
        proof
      )
      await AnimaVerseCollectionInstance.setGameWinnersMinting(true)
      await AnimaVerseCollectionInstance.connect(addr1).gameWinnersMint(gameIndex, {
        value: wlMintPrice,
      })
      const balance = await AnimaVerseCollectionInstance.balanceOf(addr1.address)
      expect(balance.toNumber()).to.equal(1)
    })
  })
})
