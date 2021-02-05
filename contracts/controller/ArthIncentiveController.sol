// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import {Math} from '../libraries/Math.sol';
import {Setters} from './Setters.sol';
import {IIncentiveController} from '../interfaces/IIncentiveController.sol';
import {Epoch} from '../Epoch.sol';
import {IBurnableERC20} from '../interfaces/IBurnableERC20.sol';

/**
 * NOTE: Contract ArthswapV1Pair should be the owner of this controller.
 */
contract ArthIncentiveController is IIncentiveController, Setters, Epoch {
    /**
     * Constructor.
     */
    constructor(
        address _pairAddress,
        address _protocolTokenAddress,
        address _incentiveToken,
        bool _isTokenAProtocolToken,
        uint256 _rewardPerHour
    ) public Epoch(60 * 60, block.timestamp, 0) {
        pairAddress = _pairAddress;
        protocolTokenAddress = _protocolTokenAddress;
        incentiveToken = IBurnableERC20(_incentiveToken);
        isTokenAProtocolToken = _isTokenAProtocolToken;
        rewardPerHour = _rewardPerHour;

        expectedVolumePerHour = 1000 * 1e18;
        availableRewardThisHour = rewardPerHour;
    }

    function updateForEpoch() private {
        expectedVolumePerHour = Math.max(currentVolumPerHour, 1);
        availableRewardThisHour = rewardPerHour;
        currentVolumPerHour = 0;

        lastExecutedAt = block.timestamp;
    }

    function estimatePenaltyToCharge(
        uint256 price,
        uint256 targetPrice,
        uint256 liquidity,
        uint256 sellVolume
    ) public pure returns (uint256) {
        // % of pool = sellVolume / liquidity
        // % of deviation from target price = (tgt_price - price) / price
        // amountToburn = sellVolume * % of deviation from target price * % of pool * 100

        uint256 percentOfPool = sellVolume.mul(1e18).div(liquidity);
        uint256 deviationFromTarget = targetPrice.sub(price).mul(1e18).div(targetPrice);

        // NOTE: Shouldn't this be multiplied by 10000 instead of 100
        // NOTE: multiplication by 100, is removed in the mock controller
        return sellVolume.mul(deviationFromTarget).mul(percentOfPool).div(uint256(1e18).mul(1e18));
    }

    function estimateRewardToGive(uint256 buyVolume) public view returns (uint256) {
        return Math.min(buyVolume.mul(rewardPerHour).div(expectedVolumePerHour), availableRewardThisHour);
    }

    /**
     * Mutations.
     */
    function _penalizeTrade(
        uint256 price,
        uint256 targetPrice,
        uint256 sellVolume,
        uint256 liquidity,
        address to
    ) private {
        uint256 amountToBurn = estimatePenaltyToCharge(price, targetPrice, liquidity, sellVolume);

        if (amountToBurn > 0) {
            // NOTE: amount has to be approved from frontend.
            // Burn and charge penalty.
            incentiveToken.burnFrom(to, amountToBurn);
        }
    }

    function _incentiviseTrade(uint256 buyVolume, address to) private {
        // Calculate the amount as per volumne and rate.
        uint256 amountToReward = estimateRewardToGive(buyVolume);

        if (amountToReward > 0) {
            availableRewardThisHour = availableRewardThisHour.sub(amountToReward);

            // Send reward to the appropriate address.
            incentiveToken.transfer(to, amountToReward);
        }
    }

    /**
     * This is the function that burns the MAHA and returns how much ARTH should
     * actually be spent.
     *
     * Note we are always selling tokenA.
     */
    function conductChecks(
        uint112 reserveA,
        uint112 reserveB,
        uint256 priceALast,
        uint256 priceBLast,
        uint256 amountOutA,
        uint256 amountOutB,
        uint256 amountInA,
        uint256 amountInB,
        address from,
        address to
    ) external onlyPair {
        if (isTokenAProtocolToken) {
            // then A is ARTH
            _conductChecks(reserveA, priceALast, amountOutA, amountInA, to);
        } else {
            // then B is ARTH
            _conductChecks(reserveB, priceBLast, amountOutB, amountInB, to);
        }
    }

    function _conductChecks(
        uint112 reserveA, // ARTH liquidity
        uint256 priceA, // ARTH price
        uint256 amountOutA, // ARTH being bought
        uint256 amountInA, // ARTH being sold
        address to
    ) private {
        // capture volume and snapshot it every hour
        currentVolumPerHour = currentVolumPerHour.add(amountOutA).add(amountInA);
        if (getCurrentEpoch() >= getNextEpoch()) updateForEpoch();

        // Check if we are selling and if we are blow the target price?
        if (amountInA > 0) {
            // Check if we are below the targetPrice.
            uint256 penaltyTargetPrice = getPenaltyPrice();

            if (priceA < penaltyTargetPrice) {
                // is the user expecting some DAI? if so then this is a sell order
                // Calculate the amount of tokens sent.
                _penalizeTrade(priceA, penaltyTargetPrice, amountInA, reserveA, to);

                // stop here to save gas
                return;
            }
        }

        // Check if we are buying and below the target price
        if (amountOutA > 0 && priceA < getRewardIncentivePrice()) {
            // is the user expecting some ARTH? if so then this is a sell order
            // If we are buying the main protocol token, then we incentivize the tx sender.
            _incentiviseTrade(amountOutA, to);
        }
    }
}
