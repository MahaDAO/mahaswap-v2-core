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
    '0x6ee5486e6cd36959be533921217a6dad1d3d7673', // pair address
    '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // target token (UNI)
    '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // incentive token (UNI)
    true, // _isTokenAProtocolToken,
    100000, // rewardPerHour
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
