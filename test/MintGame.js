const keccak256 = require('keccak256')
const { expect } = require('chai')
const { MerkleTree } = require('merkletreejs')
const { generateGame, getLeaf } = require('./aux')

describe('Mint Game contract', function () {
  let AnimaVerseMintGameInstance
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
    AnimaVerseMintGameInstance = await AnimaVerseMintGame.deploy('')
    await AnimaVerseMintGameInstance.setGamesRoot(merkleTree.getRoot())
  })

  // prevent double submit one id
  describe('Deployment', function () {
    it('Should set the right merkle root', async function () {
      const root = await AnimaVerseMintGameInstance.gamesMerkleRoot()
      expect(root.substring(2)).to.equal(merkleTree.getRoot().toString('hex'))
    })
  })

  describe('Game Logic', function () {
    it('Should submit the right answer', async function () {
      const gameIndex = 1
      const proof = merkleTree.getHexProof(getLeaf(games[gameIndex]))
      await AnimaVerseMintGameInstance.connect(addr1).submitGameScore(
        gameIndex,
        games[gameIndex].score,
        games[gameIndex].sr,
        proof
      )
      const winner1 = await AnimaVerseMintGameInstance.ownerOf(gameIndex)
      expect(winner1).to.equal(addr1.address)
    })

    it('Should not resubmit the right answer', async function () {
      const gameIndex = 1
      const proof = merkleTree.getHexProof(getLeaf(games[gameIndex]))
      await AnimaVerseMintGameInstance.connect(addr1).submitGameScore(
        gameIndex,
        games[gameIndex].score,
        games[gameIndex].sr,
        proof
      )
      const secondAnswer = AnimaVerseMintGameInstance.connect(addr2).submitGameScore(
        gameIndex,
        games[gameIndex].score,
        games[gameIndex].sr,
        proof
      )
      await expect(secondAnswer).to.be.throw
    })

    it('Should not submit the false answer', async function () {
      const gameIndex = 0
      const proof = merkleTree.getHexProof(getLeaf(games[gameIndex + 1]))
      await expect(
        AnimaVerseMintGameInstance.connect(addr1).submitGameScore(
          gameIndex,
          games[gameIndex].score,
          games[gameIndex].sr,
          proof
        )
      ).to.be.throw
    })

    it('Should not able to transfer', async function () {
      const gameIndex = 0
      const proof = merkleTree.getHexProof(getLeaf(games[gameIndex]))
      await AnimaVerseMintGameInstance.connect(addr1).submitGameScore(
        gameIndex,
        games[gameIndex].score,
        games[gameIndex].sr,
        proof
      )
      const res = AnimaVerseMintGameInstance.connect(addr1).transferFrom(addr1, addr2, 0)
      await expect(res).to.be.throw
    })
  })
})
