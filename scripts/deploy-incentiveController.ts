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
    '0x7e53072c6ca9104c60362586d9080a22ea366e91', // target token (ARTH)
    '0xb4d930279552397bba2ee473229f89ec245bc365', // incentive token (NAHA)
    "250000000000000000000", // rewardPerHour
    "61538461540000000" // ARTH to MAHA price
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
