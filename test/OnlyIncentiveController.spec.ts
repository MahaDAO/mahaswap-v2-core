import { Contract } from 'ethers'
import chai, { expect } from 'chai'
import { parseEther } from 'ethers/utils'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './shared/utilities'
import MockController from '../build/MockController.json'
import MockBurnableERC20 from '../build/MockBurnableERC20.json'


chai.use(solidity)


const overrides = { gasLimit: 9999999 }
const sellCases: any[][] = [
  [
    parseEther('1000000'), // Represents reserveA for mock Controller contract.
    parseEther('0.60'), // Represents priceA.
    parseEther('0'), // Represents amountOutA.
    parseEther('10000'), // Represents amountInA.
    100000, // Penalty multiplier.
    parseEther('320') // Represents expected penalty as pre excel sheet.
  ],
  [
    parseEther('1000000'),
    parseEther('0.20'),
    parseEther('0'),
    parseEther('10000'),
    100000,
    parseEther('640')
  ],
  [
    parseEther('1000000'),
    parseEther('0.90'),
    parseEther('0'),
    parseEther('10000'),
    100000,
    parseEther('80')
  ],
  [
    parseEther('10000000'),
    parseEther('0.90'),
    parseEther('0'),
    parseEther('10000'),
    100000,
    parseEther('80')
  ],
  [
    parseEther('100000000'),
    parseEther('0.90'),
    parseEther('0'),
    parseEther('10000'),
    200000,
    parseEther('160')
  ],
  [
    parseEther('100000'),
    parseEther('0.60'),
    parseEther('0'),
    parseEther('10000'),
    100000,
    parseEther('320')
  ]
]

const buyCases: any[][] = [
  [
    parseEther('1000000'),  // Represents reserveA for mock Controller contract.
    parseEther('0.60'),  // Represents priceA for mock Controller contract.
    parseEther('10000'), // Represents amountOutA for mock Controller contract.
    parseEther('0'),  // Represents amountInA for mock Controller contract.
    1000000, // Reward multiplier.
    parseEther(`50`) // Represents expected rewards as per the excel sheet(in $MAHA).
  ],
  [
    parseEther('1000000'),
    parseEther('0.20'),
    parseEther('10000'),
    parseEther('0'),
    100000,
    parseEther(`5`)
  ],
  [
    parseEther('1000000'),
    parseEther('0.90'),
    parseEther('10000'),
    parseEther('0'),
    200000,
    parseEther(`10`)
  ],
  [
    parseEther('10000000'),
    parseEther('0.90'),
    parseEther('10000'),
    parseEther('0'),
    100000,
    parseEther(`0.50`)
  ],
  [
    parseEther('100000000'),
    parseEther('0.90'),
    parseEther('10000'),
    parseEther('0'),
    100000,
    parseEther(`0.05`)
  ],
  [
    parseEther('100000000'),
    parseEther('0.99'),
    parseEther('100000'),
    parseEther('0'),
    100000,
    parseEther(`0.50`)
  ],
  [
    parseEther('100000'),
    parseEther('0.60'),
    parseEther('10000'),
    parseEther('0'),
    100000,
    parseEther(`50`)
  ],
]



describe('OnlyIncentiveController', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })

  let controller: Contract
  let incentiveToken: Contract
  const [wallet, other] = provider.getWallets()

  beforeEach(async () => {
    controller = await deployContract(wallet, MockController, [Math.floor(Date.now() / 1000)], overrides)
    incentiveToken = await deployContract(wallet, MockBurnableERC20, [expandTo18Decimals(1000000000)], overrides)

    await controller.connect(wallet).setEcosystemFund(other.address)
    await controller.connect(wallet).setMahaPerEpoch(expandTo18Decimals(500))

    await controller.setRewardPrice(expandTo18Decimals(1));
    await controller.setPenaltyPrice(expandTo18Decimals(1));
    await controller.setIncentiveToken(incentiveToken.address);
  })

  describe('Sell', () => {
    sellCases.forEach((testCase, i) => {
      beforeEach(async () => await controller.setArthToMahaRate(parseEther('0.08')));

      it(`conductChecks:penalty:${i}`, async () => {
        // Here, other is treated as an ecosystem fund.
        const oldBalance = await incentiveToken.balanceOf(wallet.address)
        const oldFundBalance = await incentiveToken.balanceOf(other.address)
        const oldControllerBalance = await incentiveToken.balanceOf(controller.address)

        await controller.setPenaltyMultiplier(testCase[testCase.length - 2]);

        await incentiveToken.approve(controller.address, oldBalance);

        await controller.conductChecks(
          testCase[0],
          testCase[1],
          testCase[2],
          testCase[3],
          wallet.address
        )

        expect(
          await incentiveToken.balanceOf(wallet.address)
        ).to.lt(oldBalance);
        expect(
          await incentiveToken.balanceOf(other.address)
        ).to.gt(oldFundBalance);
        expect(
          await incentiveToken.balanceOf(controller.address)
        ).to.gt(oldControllerBalance);

        const penaltyCharged = oldBalance.sub(await incentiveToken.balanceOf(wallet.address))

        const expectedControllerBalance = penaltyCharged.mul(await controller.penaltyToKeep()).div(100);
        const expectedFundBalance = penaltyCharged.mul(await controller.penaltyToRedirect()).div(100);

        expect(
          await incentiveToken.balanceOf(other.address)
        ).to.eq(oldFundBalance.add(expectedFundBalance));
        expect(
          await incentiveToken.balanceOf(controller.address)
        ).to.eq(oldControllerBalance.add(expectedControllerBalance));

        expect(
          penaltyCharged
        ).to.eq(testCase[testCase.length - 1])
      })
    })
  })

  describe('Buy', () => {
    buyCases.forEach((testCase, i) => {
      it(`conductChecks:reward:${i}`, async () => {
        await controller.setRewardMultiplier(testCase[testCase.length - 2]);

        await incentiveToken.transfer(controller.address, await incentiveToken.balanceOf(wallet.address));
        const oldBalance = await incentiveToken.balanceOf(wallet.address);

        await incentiveToken.approve(controller.address, oldBalance);

        await controller.conductChecks(
          testCase[0],
          testCase[1],
          testCase[2],
          testCase[3],
          wallet.address
        )

        const reward = (await incentiveToken.balanceOf(wallet.address)).sub(oldBalance)

        expect(
          (await incentiveToken.balanceOf(wallet.address))
        ).to.gt(oldBalance);

        expect(
          reward
        ).to.eq(testCase[testCase.length - 1]);
      })
    })
  })
})
