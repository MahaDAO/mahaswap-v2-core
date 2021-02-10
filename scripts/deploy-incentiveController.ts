import { network, ethers } from 'hardhat';


async function main() {
  // Fetch the provider.
  const { provider } = ethers;

  const estimateGasPrice = await provider.getGasPrice();
  const gasPrice = estimateGasPrice.mul(3).div(2);
  console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);

  // Fetch the wallet accounts.
  const [operator,] = await ethers.getSigners();


  // Fetch contract factories.
  const contract = await ethers.getContractFactory('ArthIncentiveController');


  // Deploy new treasury.
  const paramsMainnet = [
    '0x1C36D9E60cac6893652b74E357f3829A0f5095e0', // pair address
    '0x0e3cc2c4fb9252d17d07c67135e48536071735d9', // target token (ARTH)
    '0xb4d930279552397bba2ee473229f89ec245bc365', // incentive token (NAHA)
    "500000000000000000000", // rewardPerHour
    "61538461540000000" // ARTH to MAHA price
  ]

  const paramsRopsten = [
    '0x8c85541cc02e88242cb706f88f0724ea874dfb0e', // pair address
    '0x5ac2a32bfa475765558cea2a0fe0bf0207d58ca4', // target token (ARTH)
    '0xcd24efb0f7285cb923cab11a85fbdb1523f10011', // incentive token (NAHA)
    "250000000000000000000", // rewardPerHour
    "1000000000000000000" // ARTH to MAHA price
  ]

  const paramsGoreli = [
    '0x38eBdcB14674Ea32c982d7c93CcDf28F06a5c7a6', // pair address
    '0xfa1c36f01fea68726ec60cf1f050783aa9d1076c', // target token (ARTH)
    '0x981f0d72650583d4d6961def6c186d84d9e0f2b9', // incentive token (NAHA)
    "250000000000000000000", // rewardPerHour
    "1000000000000000000" // ARTH to MAHA price
  ]


  const params = paramsMainnet

  console.log(params)
  const factory = await contract.connect(operator).deploy(...params);

  console.log(` - operator is ${operator.address}`)
  console.log(` - controller at address ${factory.address}`)
}


main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
