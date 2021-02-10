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
  const MahaswapV1Factory = await ethers.getContractFactory('MahaswapV1Factory');


  // Deploy new treasury.

  const params = [
    '0xeccE08c2636820a81FC0c805dBDC7D846636bbc4'
  ]

  const factory = await MahaswapV1Factory.connect(operator).deploy(...params);

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
