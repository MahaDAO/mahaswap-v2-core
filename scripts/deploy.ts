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
  const ArthswapV1Factory = await ethers.getContractFactory('ArthswapV1Factory');


  // Deploy new treasury.

  const params = [
    '0x0000000000000000000000000000000000000000'
  ]

  const factory = await ArthswapV1Factory.connect(operator).deploy(...params);

  console.log(`\nTreasury details: `)
  console.log(` - operator is ${operator.address}`)
  console.log(` - factory at address ${factory.address}`)
}


main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
