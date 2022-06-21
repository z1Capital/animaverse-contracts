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

  // complex batches
  // change withdraw share
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
      const basis = BigNumber.from(10000)
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
        startBalanceAddr1.add(value.mul(communityRoyaltyShare).div(basis)).toString()
      )
      expect(endBalanceAddr2.toString()).to.equal(
        startBalanceAddr2.add(value.mul(basis.sub(communityRoyaltyShare)).div(basis)).toString()
      )
    })
  
    it('withdraw token', async function () {
      const basis = BigNumber.from(10000)
      const value = BigNumber.from('10').pow(18)
      const communityRoyaltyShare = await AnimaVerseCollectionInstance.communityRoyaltyShare()

      await AnimaVerseCollectionInstance.setCommunityWithdrawMainAccount(addr1.address)
      await AnimaVerseCollectionInstance.setArtistsWithdrawAccount(addr2.address)

      const AnimaVerseToken = await ethers.getContractFactory('AnimaverseToken')
      const AnimaVerseTokenInstance = await AnimaVerseToken.deploy()

      await AnimaVerseTokenInstance.mint(AnimaVerseCollectionInstance.address, value)
      const contractBalance = await AnimaVerseTokenInstance.balanceOf(AnimaVerseCollectionInstance.address)
      expect(contractBalance.toString()).to.equal(value.toString())

      await AnimaVerseCollectionInstance.withdrawTokens(AnimaVerseTokenInstance.address, value)
      const balanceAddr1 = await AnimaVerseTokenInstance.balanceOf(addr1.address)
      const balanceAddr2 = await AnimaVerseTokenInstance.balanceOf(addr2.address)

      expect(balanceAddr1.toString()).to.equal(value.mul(communityRoyaltyShare).div(basis).toString())
      expect(balanceAddr2.toString()).to.equal(value.mul(basis.sub(communityRoyaltyShare)).div(basis).toString())
    })
  })
})
