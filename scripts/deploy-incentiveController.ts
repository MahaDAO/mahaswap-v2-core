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
    '0x8c85541cc02e88242cb706f88f0724ea874dfb0e', // pair address
    '0x5ac2a32bfa475765558cea2a0fe0bf0207d58ca4', // target token (ARTH)
    '0xcd24efb0f7285cb923cab11a85fbdb1523f10011', // incentive token (NAHA)
    "250000000000000000000", // rewardPerHour
    "87000000000000000" // ARTH to MAHA price
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
