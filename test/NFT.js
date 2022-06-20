const { expect } = require('chai')

describe('NFT contract', function () {
  let AnimaVerseCollectionInstance
  let owner
  let addr1
  let addr2
  let addrs

  beforeEach(async function () {
    ;[owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    const AnimaVerseCollection = await ethers.getContractFactory('AnimaVerseCollectionTest')
    AnimaVerseCollectionInstance = await AnimaVerseCollection.deploy('', '')
  })

  describe('Deployment', function () {
    it('Should set the right owner for contract', async function () {
      expect(await AnimaVerseCollectionInstance.owner()).to.equal(owner.address)
    })
  })

  // prevent double mint of winner
  // withdraw
  describe('NFT Mint', function () {
    it('Mint', async function () {
      const mintCount = await AnimaVerseCollectionInstance.maxAddressRoundMint()
      const mintPrice = await AnimaVerseCollectionInstance.mintPrice()
      const minter = addrs[0]

      await AnimaVerseCollectionInstance.connect(minter).mint(mintCount, {
        value: mintPrice.mul(mintCount),
      })
      const balance = await AnimaVerseCollectionInstance.balanceOf(minter.address)
      expect(balance.toNumber()).to.equal(mintCount)
    })

    it('Add batch', async function () {
      const price = '100'
      await AnimaVerseCollectionInstance.setNewRound(price, 5002, 3, 1)
      const mintPrice = await AnimaVerseCollectionInstance.mintPrice()
      expect(mintPrice.toString()).to.equal(price)
    })
  })
})
