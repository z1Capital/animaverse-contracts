const { expect } = require('chai')
const { BigNumber } = require('ethers')

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

  // withdraw
  // withdraw token
  // change withdraw share
  // change withdraw addresses
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

    it('Prevent double Mint', async function () {
      const minter = addrs[0]
      const mintCount = await AnimaVerseCollectionInstance.maxAddressRoundMint()
      const mintPrice = await AnimaVerseCollectionInstance.mintPrice()

      await AnimaVerseCollectionInstance.connect(minter).mint(mintCount, {
        value: mintPrice.mul(mintCount),
      })
      const secondMint = AnimaVerseCollectionInstance.connect(minter).mint(mintCount, {
        value: mintPrice.mul(mintCount),
      })
      await expect(secondMint).to.be.throw
    })

    it('Add batch ', async function () {
      const price = BigNumber.from('10').pow(16)
      const count = 1
      await AnimaVerseCollectionInstance.setNewRound(price, 5002, 3, count)
      const mintPrice = await AnimaVerseCollectionInstance.mintPrice()
      expect(mintPrice.toString()).to.equal(price.toString())
    })

    it('batch mint', async function () {
      const minter = addrs[0]
      const price = BigNumber.from('10').pow(16)
      const count = 1
      await AnimaVerseCollectionInstance.setNewRound(price, 5002, 3, count)
      await AnimaVerseCollectionInstance.connect(minter).mint(count, {
        value: price.mul(count),
      })
      const balance = await AnimaVerseCollectionInstance.balanceOf(minter.address)
      expect(balance.toString()).to.equal(count.toString())
    })

    it('withdraw', async function () {
      const minter = addrs[0]
      const price = BigNumber.from('10').pow(16)
      const count = 1
      const startBalanceAddr1 = await AnimaVerseCollectionInstance.provider.getBalance(addr1.address)
      const startBalanceAddr2 = await AnimaVerseCollectionInstance.provider.getBalance(addr2.address)
      const communityRoyaltyShare = await AnimaVerseCollectionInstance.communityRoyaltyShare()
      await AnimaVerseCollectionInstance.setCommunityWithdrawMainAccount(addr1.address)
      await AnimaVerseCollectionInstance.setArtistsWithdrawAccount(addr2.address)

      await AnimaVerseCollectionInstance.setNewRound(price, 5002, 3, count)
      const value = price.mul(count)
      await AnimaVerseCollectionInstance.connect(minter).mint(count, {
        value,
      })

      await AnimaVerseCollectionInstance.withdraw(value)
      const endBalanceAddr1 = await AnimaVerseCollectionInstance.provider.getBalance(addr1.address)
      const endBalanceAddr2 = await AnimaVerseCollectionInstance.provider.getBalance(addr2.address)
      expect(endBalanceAddr1.toString()).to.equal(
        startBalanceAddr1.add(price.mul(communityRoyaltyShare).div(10000)).toString()
      )
      expect(endBalanceAddr2.toString()).to.equal(
        startBalanceAddr2.add(price.mul(BigNumber.from(10000).sub(communityRoyaltyShare)).div(10000)).toString()
      )
    })
  })
})
