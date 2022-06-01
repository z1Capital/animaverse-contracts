const hre = require('hardhat')

async function main() {
  const [deployer] = await hre.ethers.getSigners()
  console.log('Deploying contract with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  const AnimaVerseMintGame = await hre.ethers.getContractFactory('AnimaVerseMintGame')
  const animaVerseMintGame = await AnimaVerseMintGame.deploy(
    'ipfs://',
    'ipfs://',
  )
  const res = await animaVerseMintGame.deployed()
  console.log('AnimaVerse Mint Game deployed to:', animaVerseMintGame.address)
  console.log('Gas Used:', res.deployTransaction.gasLimit.toString())
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
