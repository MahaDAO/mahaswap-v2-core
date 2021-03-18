import { network, ethers } from 'hardhat'

async function main() {
  // Fetch the provider.
  const { provider } = ethers

  const estimateGasPrice = await provider.getGasPrice()
  const gasPrice = estimateGasPrice.mul(3).div(2)
  console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`)

  // Fetch the wallet accounts.
  const [operator] = await ethers.getSigners()

  // Fetch contract factories.
  const contract = await ethers.getContractFactory('ArthEthIncentiveController')

  // Deploy new treasury.
  const paramsMainnet = [
    '0xe207492fad13324b3b80b1a4324a203b61fc11a6', // pair address
    '0x0e3cc2c4fb9252d17d07c67135e48536071735d9', // target token (ARTH)
    '0x5aC2A32BFa475765558CEa2A0Fe0bF0207D58Ca4', // ecosystem fund
    '0xb4d930279552397bba2ee473229f89ec245bc365', // incentive token (NAHA)
    '500000000000000000000', // rewardPerEpoch
    '111111111100000000', // ARTH to MAHA price
    12 * 60 * 60, // period
    '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419'
  ]

  const paramsRopsten = [
    '0x8c85541cc02e88242cb706f88f0724ea874dfb0e', // pair address
    '0x5ac2a32bfa475765558cea2a0fe0bf0207d58ca4', // target token (ARTH)
    '0x5ac2a32bfa475765558cea2a0fe0bf0207d58ca4', // ecosystem fund
    '0xcd24efb0f7285cb923cab11a85fbdb1523f10011', // incentive token (NAHA)
    '500000000000000000000', // rewardPerEpoch
    '1000000000000000000', // ARTH to MAHA price
    5 * 60 // period
  ]

  const paramsGoreli = [
    '0x38eBdcB14674Ea32c982d7c93CcDf28F06a5c7a6', // pair address
    '0xfa1c36f01fea68726ec60cf1f050783aa9d1076c', // target token (ARTH)
    '0xfa1c36f01fea68726ec60cf1f050783aa9d1076c', // ecosystem fund
    '0x981f0d72650583d4d6961def6c186d84d9e0f2b9', // incentive token (NAHA)
    '500000000000000000000', // rewardPerEpoch
    '1000000000000000000', // ARTH to MAHA price
    5 * 60 // period
  ]

  const params = paramsMainnet

  console.log(params)
  const factory = await contract.connect(operator).deploy(...params)

  console.log(` - operator is ${operator.address}`)
  console.log(` - controller at address ${factory.address}`)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
