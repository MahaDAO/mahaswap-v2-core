import { Contract } from 'ethers'
import chai, { expect } from 'chai'
import { parseEther } from 'ethers/utils'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './shared/utilities'
import MockController from '../build/MockController.json'
import MockBurnableERC20 from '../build/MockBurnableERC20.json'


chai.use(solidity)


const overrides = { gasLimit: 9999999 }


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
    })

    const sellCases: any[][] = [
        [
            parseEther('1000000'), // reserveA for mock Controller contract.
            parseEther('0.60'), // priceA
            parseEther('0'), // amountOutA
            parseEther('10000'), // amountInA
        ],
        [
            parseEther('1000000'),
            parseEther('0.20'),
            parseEther('0'),
            parseEther('10000'),
        ],
        [
            parseEther('1000000'),
            parseEther('0.10'),
            parseEther('0'),
            parseEther('10000'),
        ],
        [
            parseEther('1000000'),
            parseEther('0.90'),
            parseEther('0'),
            parseEther('10000'),
        ],
        [
            parseEther('10000000'),
            parseEther('0.90'),
            parseEther('0'),
            parseEther('100000'),
        ],
        [
            parseEther('10000000'),
            parseEther('0.90'),
            parseEther('0'),
            parseEther('10000'),
        ],
        [
            parseEther('100000'),
            parseEther('0.60'),
            parseEther('0'),
            parseEther('100000'),
        ],
    ]

    sellCases.forEach((testCase, i) => {
        it(`conductChecks:penalty:${i}`, async () => {
            // setting variables for mock to run some simulations.
            await controller.setPenaltyPrice(expandTo18Decimals(1));
            await controller.setIncentiveToken(incentiveToken.address);

            const oldBalance = await incentiveToken.balanceOf(wallet.address);

            await incentiveToken.approve(controller.address, oldBalance);

            // checking
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

            console.log(`Sell:case:${i}`, oldBalance.sub(await incentiveToken.balanceOf(wallet.address)).toString());
        })
    })

    const buyCases: any[][] = [
        [
            parseEther('1000000'),  // reserveA for mock Controller contract.
            parseEther('0.60'),  // reserveA for mock Controller contract.
            parseEther('10000'), // reserveA for mock Controller contract. 
            parseEther('0'),  // reserveA for mock Controller contract.
            parseEther('100000') // Exp. volume in 1hr.
        ],
        [
            parseEther('1000000'),
            parseEther('0.20'),
            parseEther('10000'),
            parseEther('0'),
            parseEther('1000000') // Exp. volume in 1hr.
        ],
        [
            parseEther('1000000'),
            parseEther('0.10'),
            parseEther('10000'),
            parseEther('0'),
            parseEther('20000000') // Exp. volume in 1hr.
        ],
        // [
        //     parseEther('1000000'),
        //     parseEther('0.90'),
        //     parseEther('10000'),
        //     parseEther('0'),
        // ],
        // [
        //     parseEther('10000000'),
        //     parseEther('0.90'),
        //     parseEther('10000'),
        //     parseEther('0'),
        // ],
        // [
        //     parseEther('10000000'),
        //     parseEther('0.90'),
        //     parseEther('10000'),
        //     parseEther('0'),
        // ],
        // [
        //     parseEther('100000'),
        //     parseEther('0.60'),
        //     parseEther('10000'),
        //     parseEther('0')
        // ],
    ]

    buyCases.forEach((testCase, i) => {
        it(`conductChecks:reward:${i}`, async () => {
            // setting the varibales for mock to run some simulations.
            await controller.setExpVolumePerHour(testCase[testCase.length - 1]);

            await controller.setPenaltyPrice(expandTo18Decimals(1));
            await controller.setIncentiveToken(incentiveToken.address);

            await incentiveToken.transfer(controller.address, await incentiveToken.balanceOf(wallet.address));
            const oldBalance = await incentiveToken.balanceOf(wallet.address);

            await incentiveToken.approve(controller.address, oldBalance);

            // checking.
            await controller.conductChecks(
                testCase[0],
                testCase[1],
                testCase[2],
                testCase[3],
                wallet.address
            )

            expect(
                await incentiveToken.balanceOf(wallet.address)
            ).to.gt(oldBalance);

            console.log(`Buy:case:${i}`, (await incentiveToken.balanceOf(wallet.address)).sub(oldBalance).toString());
        })
    })
})
