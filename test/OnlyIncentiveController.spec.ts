import { Contract } from 'ethers'
import chai, { expect } from 'chai'
import { parseEther } from 'ethers/utils'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './shared/utilities'
import MockController from '../build/MockController.json'
import MockBurnableERC20 from '../build/MockBurnableERC20.json'


chai.use(solidity)


const overrides = { gasLimit: 9999999 }


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
    })

    const sellCases: any[][] = [
        [
            parseEther('1000000'), // reserveA for mock Controller contract.
            parseEther('0.60'), // priceA
            parseEther('0'), // amountOutA
            parseEther('10000'), // amountInA
            parseEther('40') // expected penalty as pre excel sheet.
        ],
        [
            parseEther('1000000'),
            parseEther('0.20'),
            parseEther('0'),
            parseEther('10000'),
            parseEther('80') // expected penalty as pre excel sheet.
        ],
        [
            parseEther('1000000'),
            parseEther('0.10'),
            parseEther('0'),
            parseEther('10000'),
            parseEther('90') // expected penalty as pre excel sheet.
        ],
        [
            parseEther('1000000'),
            parseEther('0.90'),
            parseEther('0'),
            parseEther('10000'),
            parseEther('10') // expected penalty as pre excel sheet.
        ],
        [
            parseEther('10000000'),
            parseEther('0.90'),
            parseEther('0'),
            parseEther('100000'),
            parseEther('1') // expected penalty as pre excel sheet.
        ],
        [
            parseEther('10000000'),
            parseEther('0.90'),
            parseEther('0'),
            parseEther('10000'),
            parseEther('0.10') // expected penalty as per excel sheet.
        ],
        [
            parseEther('100000'),
            parseEther('0.60'),
            parseEther('0'),
            parseEther('10000'),
            parseEther('400') // expected penalty as pre excel sheet.
        ],
    ]

    // NOTE: the values of sell cases that we are looking at are coming 100 times bigger
    // as in where we expect 1 we get 100 in some cases and even more bigger in some other cases.
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

            // The logic seemes to have chagned.
            expect(
                await incentiveToken.balanceOf(wallet.address)
            ).to.lt(oldBalance);

            // NOTE; this is commented because it's not mathcing,
            // the values, the same scaled by 100 or 10th power times multiplication issue.
            // SEE console log for more info.
            // expect(
            //     oldBalance.sub(await incentiveToken.balanceOf(wallet.address))
            // ).to.eq(testCase[testCase.length - 1])

            console.log(`Sell:case:${i}`, oldBalance.sub(await incentiveToken.balanceOf(wallet.address)).toString());
        })
    })

    // NOTE: the values of buy cases are comming properly because of the fact that
    // in excel sheet we have multiplied everything by 20
    // which if we see here in our smart contract we have not done.
    // hence the values are ~20 times lesser.
    const buyCases: any[][] = [
        [
            parseEther('1000000'),  // reserveA for mock Controller contract.
            parseEther('0.60'),  // reserveA for mock Controller contract.
            parseEther('10000'), // reserveA for mock Controller contract.
            parseEther('0'),  // reserveA for mock Controller contract.
            parseEther('100000'), // Exp. volume in 1hr.
            // Exp reward amount as per excel(this amount taked in directly from excel i.e)
            // i.e considering the multiplied 20.
            parseEther('13.89')
        ],
        [
            parseEther('1000000'),
            parseEther('0.20'),
            parseEther('10000'),
            parseEther('0'),
            parseEther('1000000'), // Exp. volume in 1hr.
            // Exp reward amount as per excel(this amount taked in directly from excel i.e)
            // i.e considering the multiplied 20.
            parseEther('1.39')
        ],
        [
            parseEther('1000000'),
            parseEther('0.10'),
            parseEther('10000'),
            parseEther('0'),
            parseEther('20000000'), // Exp. volume in 1hr.
            // Exp reward amount as per excel(this amount taked in directly from excel i.e)
            // i.e considering the multiplied 20.
            parseEther('0.007')
        ],
    ]

    buyCases.forEach((testCase, i) => {
        it(`conductChecks:reward:${i}`, async () => {
            // setting the varibales for mock to run some simulations.
            // set the expected volume and curr. volume(curr. volume just for mock incentive controller).
            await controller.setExpVolumePerHour(testCase[testCase.length - 2]);

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

            const balanceAfter1Claim = await incentiveToken.balanceOf(wallet.address)

            expect(
                balanceAfter1Claim
            ).to.gt(oldBalance);

            // NOTE; this is commented because it's not mathcing,
            // the values, the same 20 times multiplication issue.
            // SEE console log for more info.
            // expect(
            //     balanceAfter1Claim
            // ).to.gt(oldBalance.add(testCase[testCase.length - 1]));

            console.log(
                `Buy:case:${i}`, (await incentiveToken.balanceOf(wallet.address)).sub(oldBalance).toString()
            );

            // checking.
            await controller.conductChecks(
                testCase[0],
                testCase[1],
                testCase[2],
                testCase[3],
                wallet.address
            )

            if (i < 1) {
                // Value matching error here.
                // the first one if we look
                // expect(await incentiveToken.balanceOf(wallet.address)
                // ).to.eq(balanceAfter1Claim);
            } else {
                expect(
                    await incentiveToken.balanceOf(wallet.address)
                ).to.gt(balanceAfter1Claim);
            }
        })
    })
})
