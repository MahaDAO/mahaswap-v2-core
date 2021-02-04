import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { MaxUint256 } from 'ethers/constants'
import { bigNumberify, hexlify, keccak256, defaultAbiCoder, toUtf8Bytes } from 'ethers/utils'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import { ecsign } from 'ethereumjs-util'

import { expandTo18Decimals, getApprovalDigest } from './shared/utilities'

import ERC20 from '../build/ERC20.json'

chai.use(solidity)

const TOTAL_SUPPLY = expandTo18Decimals(10000)
const TEST_AMOUNT = expandTo18Decimals(10)

describe('ArthIncentiveController', () => {
    const provider = new MockProvider({
        hardfork: 'istanbul',
        mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
        gasLimit: 9999999
    })
    const [wallet, other] = provider.getWallets()

    let token: Contract
    beforeEach(async () => {
        token = await deployContract(wallet, ERC20, [TOTAL_SUPPLY])
    })

    it('permit', async () => {
        const nonce = await token.nonces(wallet.address)
        const deadline = MaxUint256
        const digest = await getApprovalDigest(
            token,
            { owner: wallet.address, spender: other.address, value: TEST_AMOUNT },
            nonce,
            deadline
        )

        const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(wallet.privateKey.slice(2), 'hex'))

        await expect(token.permit(wallet.address, other.address, TEST_AMOUNT, deadline, v, hexlify(r), hexlify(s)))
            .to.emit(token, 'Approval')
            .withArgs(wallet.address, other.address, TEST_AMOUNT)
        expect(await token.allowance(wallet.address, other.address)).to.eq(TEST_AMOUNT)
        expect(await token.nonces(wallet.address)).to.eq(bigNumberify(1))
    })
})
