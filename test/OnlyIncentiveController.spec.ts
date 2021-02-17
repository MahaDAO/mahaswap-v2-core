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
    parseEther('40') // Represents expected penalty as pre excel sheet.
  ],
  [
    parseEther('1000000'),
    parseEther('0.20'),
    parseEther('0'),
    parseEther('10000'),
    parseEther('80')
  ],
  [
    parseEther('1000000'),
    parseEther('0.10'),
    parseEther('0'),
    parseEther('10000'),
    parseEther('90')
  ],
  [
    parseEther('1000000'),
    parseEther('0.90'),
    parseEther('0'),
    parseEther('10000'),
    parseEther('10')
  ],
  [
    parseEther('10000000'),
    parseEther('0.90'),
    parseEther('0'),
    parseEther('100000'),
    parseEther('1')
  ],
  [
    parseEther('100000000'),
    parseEther('0.90'),
    parseEther('0'),
    parseEther('10000'),
    parseEther('0.10')
  ],
  [
    parseEther('100000'),
    parseEther('0.60'),
    parseEther('0'),
    parseEther('10000'),
    parseEther('400')
  ],
]

const buyCases: any[][] = [
  [
    parseEther('1000000'),  // Represents reserveA for mock Controller contract.
    parseEther('0.60'),  // Represents reserveA for mock Controller contract.
    parseEther('10000'), // Represents reserveA for mock Controller contract.
    parseEther('0'),  // Represents reserveA for mock Controller contract.
    parseEther('100000'), // Represents Exp. volume in 1hr.
    parseEther(`${13.89 / 20}`) // Represents expected rewards as per the excel sheet.
  ],
  [
    parseEther('1000000'),
    parseEther('0.20'),
    parseEther('10000'),
    parseEther('0'),
    parseEther('1000000'),
    parseEther(`${1.389 / 20}`)
  ],
  [
    parseEther('1000000'),
    parseEther('0.10'),
    parseEther('10000'),
    parseEther('0'),
    parseEther('20000000'),
    parseEther(`${1.389 / 400}`)
  ],
]



describe.only('OnlyIncentiveController', () => {
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
  })

  let rewardWith1x: any[] = [];
  let penaltiesWith1x: any[] = [];

  describe('Sell', () => {
    sellCases.forEach((testCase, i) => {
      it(`conductChecks:penalty:${i}`, async () => {
        await controller.setPenaltyPrice(expandTo18Decimals(1));
        await controller.setIncentiveToken(incentiveToken.address);

        // Here, other is treated as an ecosystem fund.
        const oldBalance = await incentiveToken.balanceOf(wallet.address)
        const oldFundBalance = await incentiveToken.balanceOf(other.address)
        const oldControllerBalance = await incentiveToken.balanceOf(controller.address)

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

        // console.log(`Sell:case:${i}`, penaltyCharged.toString());

        // expect(
        //   oldBalance.sub(await incentiveToken.balanceOf(wallet.address)).div(100)
        // ).to.eq(testCase[testCase.length - 1])

        penaltiesWith1x.push(penaltyCharged);
      })
    })
  })

  describe('Buy', () => {
    buyCases.forEach((testCase, i) => {
      it(`conductChecks:reward:${i}`, async () => {
        await controller.setExpVolumePerHour(testCase[testCase.length - 2]);

        await controller.setPenaltyPrice(expandTo18Decimals(1));
        await controller.setIncentiveToken(incentiveToken.address);

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

        const balanceAfter1Claim = await incentiveToken.balanceOf(wallet.address)

        expect(
          balanceAfter1Claim
        ).to.gt(oldBalance);

        // We use <= since, there can be precision issues in the excel file.
        expect(
          balanceAfter1Claim.sub(oldBalance)
        ).to.lte(testCase[testCase.length - 1]);

        // console.log(
        //   `Buy:case:${i}`, (await incentiveToken.balanceOf(wallet.address)).sub(oldBalance).toString()
        // );

        // console.log(balanceAfter1Claim.sub(oldBalance).toString());

        await controller.conductChecks(
          testCase[0],
          testCase[1],
          testCase[2],
          testCase[3],
          wallet.address
        )

        expect(
          await incentiveToken.balanceOf(wallet.address)
        ).to.gt(balanceAfter1Claim);

        rewardWith1x.push(
          [balanceAfter1Claim.sub(oldBalance), (await incentiveToken.balanceOf(wallet.address)).sub(balanceAfter1Claim)]
        )
      })
    })
  })

  describe('Sell, penalty 2x', () => {
    sellCases.forEach((testCase, i) => {
      beforeEach(async () => {
        await controller.connect(wallet).setPenaltyMultiplier(2);
      })

      it(`conductChecks:penalty:${i}`, async () => {
        await controller.setPenaltyPrice(expandTo18Decimals(1));
        await controller.setIncentiveToken(incentiveToken.address);

        // Here, other is treated as an ecosystem fund.
        const oldBalance = await incentiveToken.balanceOf(wallet.address)
        const oldFundBalance = await incentiveToken.balanceOf(other.address)
        const oldControllerBalance = await incentiveToken.balanceOf(controller.address)

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

        expect(penaltyCharged).to.eq(penaltiesWith1x[i].mul(2));

        // console.log(`Sell:case:${i}`, penaltyCharged.toString());

        // expect(
        //   oldBalance.sub(await incentiveToken.balanceOf(wallet.address)).div(100)
        // ).to.eq(testCase[testCase.length - 1])
      })
    })
  })

  describe('Buy reward 2x', () => {
    beforeEach(async () => {
      await controller.connect(wallet).setRewardMultiplier(2);
    })

    buyCases.forEach((testCase, i) => {
      it(`conductChecks:reward:${i}`, async () => {
        await controller.setExpVolumePerHour(testCase[testCase.length - 2]);

        await controller.setPenaltyPrice(expandTo18Decimals(1));
        await controller.setIncentiveToken(incentiveToken.address);

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

        const balanceAfter1Claim = await incentiveToken.balanceOf(wallet.address)

        // expect(balanceAfter1Claim.sub(oldBalance)).to.gt(rewardWith1x[i][0].mul(15).div(10))
        // expect(balanceAfter1Claim.sub(oldBalance)).to.lt(rewardWith1x[i][0].mul(25).div(10))
        expect(balanceAfter1Claim.sub(oldBalance)).to.eq(rewardWith1x[i][0].mul(2))

        expect(
          balanceAfter1Claim
        ).to.gt(oldBalance);

        // We use <= since, there can be precision issues in the excel file.
        expect(
          balanceAfter1Claim.sub(oldBalance)
        ).to.lte(testCase[testCase.length - 1]);

        // console.log(
        //   `Buy:case:${i}`, (await incentiveToken.balanceOf(wallet.address)).sub(oldBalance).toString()
        // );

        // console.log(balanceAfter1Claim.sub(oldBalance).toString());

        await controller.conductChecks(
          testCase[0],
          testCase[1],
          testCase[2],
          testCase[3],
          wallet.address
        )

        expect(
          await incentiveToken.balanceOf(wallet.address)
        ).to.gt(balanceAfter1Claim);

        expect((await incentiveToken.balanceOf(wallet.address)).sub(balanceAfter1Claim)).to.eq(rewardWith1x[i][1].mul(2))
      })
    })
  })
})
