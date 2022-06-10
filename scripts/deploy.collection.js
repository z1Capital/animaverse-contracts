const hre = require('hardhat')

async function main() {
  const [deployer] = await hre.ethers.getSigners()
  console.log('Deploying contract with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  const AnimaVerseCollection = await hre.ethers.getContractFactory('AnimaVerseCollectionTest')
  const animaVerseCollection = await AnimaVerseCollection.deploy(
    'https://assets.animaversedao.com/metadata',
    'https://assets.animaversedao.com/metadata/',
  )
  const res = await animaVerseCollection.deployed()
  console.log('AnimaVerse Collection deployed to:', animaVerseCollection.address)
  console.log('Gas Used:', res.deployTransaction.gasLimit.toString())
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
