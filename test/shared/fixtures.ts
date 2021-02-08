import { Contract, Wallet } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import ERC20 from '../../build/ERC20.json'
import { expandTo18Decimals } from './utilities'
import UniswapV2Pair from '../../build/MahaswapV1Pair.json'
import UniswapV2Factory from '../../build/MahaswapV1Factory.json'
import MockBurnableERC20 from '../../build/MockBurnableERC20.json'
import ArthIncentiveController from '../../build/ArthIncentiveController.json'


interface FactoryFixture {
  factory: Contract
}

const overrides = {
  gasLimit: 9999999
}

export async function factoryFixture(_: Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
  const factory = await deployContract(wallet, UniswapV2Factory, [wallet.address], overrides)
  return { factory }
}


interface PairFixture extends FactoryFixture {
  token0: Contract
  token1: Contract
  pair: Contract
}

export async function pairFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<PairFixture> {
  const { factory } = await factoryFixture(provider, [wallet])

  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)], overrides)
  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)], overrides)

  await factory.createPair(tokenA.address, tokenB.address, overrides)
  const pairAddress = await factory.getPair(tokenA.address, tokenB.address)
  const pair = new Contract(pairAddress, JSON.stringify(UniswapV2Pair.abi), provider).connect(wallet)

  const token0Address = (await pair.token0()).address
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  return { factory, token0, token1, pair }
}


interface ControllerFixture extends FactoryFixture {
  token0: Contract
  token1: Contract
  pair: Contract
  incentiveToken: Contract
  controller: Contract
}

export async function controllerFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<ControllerFixture> {
  const { factory } = await factoryFixture(provider, [wallet])

  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)], overrides)
  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)], overrides)

  await factory.createPair(tokenA.address, tokenB.address, overrides)
  const pairAddress = await factory.getPair(tokenA.address, tokenB.address)
  const pair = new Contract(pairAddress, JSON.stringify(UniswapV2Pair.abi), provider).connect(wallet)

  const incentiveToken = await deployContract(wallet, MockBurnableERC20, [expandTo18Decimals(1000000)], overrides)

  const token0Address = (await pair.token0()).address
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  const controller = await deployContract(
    wallet,
    ArthIncentiveController,
    [pairAddress, token0.address, incentiveToken.address, 1000],
    overrides
  )

  await factory.setIncentiveControllerForPair(pairAddress, controller.address);

  return { factory, token0, token1, pair, controller, incentiveToken }
}
