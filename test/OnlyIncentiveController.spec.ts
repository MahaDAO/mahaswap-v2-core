import { Contract } from 'ethers'
import chai, { expect } from 'chai'
import { BigNumber, bigNumberify } from 'ethers/utils'
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

    const cases: BigNumber[][] = [
        // [
        //     reserveA,
        //     priceALast,
        //     amountOutA,
        //     amountInA,
        //     to
        //     return amount
        // ],
        [
            10,
            8,
            0,
            2,
            1
        ]
    ].map(a => a.map(n => (typeof n === 'string' ? bigNumberify(n) : expandTo18Decimals(n))))

    cases.forEach((testCase, i) => {
        it(`conductChecks:${i}`, async () => {
            console.log((await controller.connectChecks(...(testCase.slice(0, testCase.length - 1)), overrides)))
            // expect(await controller.connectChecks(...testCase.slice(0, testCase.length - 1), overrides))
            //     .to.eq(testCase[testCase.length - 1]);
        })
    })
})
