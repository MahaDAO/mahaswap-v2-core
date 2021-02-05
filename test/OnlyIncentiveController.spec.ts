import { Contract } from 'ethers'
import chai, { expect } from 'chai'
import { BigNumber, bigNumberify, parseEther } from 'ethers/utils'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './shared/utilities'
import MockController from '../build/MockController.json'


chai.use(solidity)


const overrides = {
    gasLimit: 9999999
}


describe('OnlyIncentiveController', () => {
    const provider = new MockProvider({
        hardfork: 'istanbul',
        mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
        gasLimit: 9999999
    })

    let controller: Contract
    const [wallet, other] = provider.getWallets()

    beforeEach(async () => {
        controller = await deployContract(wallet, MockController, [Math.floor(Date.now() / 1000)], overrides)
    })

    const cases: any[][] = [
        [
            parseEther('1000000'),
            parseEther('0.60'),
            parseEther('0'),
            parseEther('10000'),
            1
        ],
    ]

    cases.forEach((testCase, i) => {
        it(`sell side conductChecks:${i}`, async () => {
            await controller.setPenaltyPrice(expandTo18Decimals(1));

            expect(
                await controller.conductChecks(
                    testCase[0],
                    testCase[1],
                    testCase[2],
                    testCase[3],
                    wallet.address
                )
            ).to.eq(testCase[testCase.length - 1]);
        })
    })
})
