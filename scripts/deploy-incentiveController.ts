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
  const params = [
    '0x38eBdcB14674Ea32c982d7c93CcDf28F06a5c7a6', // pair address
    '0xfa1c36f01fea68726ec60cf1f050783aa9d1076c', // target token (ARTH)
    '0x981f0d72650583d4d6961def6c186d84d9e0f2b9', // incentive token (NAHA)
    false, // _isTokenAProtocolToken,
    "13000000000000000000", // rewardPerHour
  ]

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
