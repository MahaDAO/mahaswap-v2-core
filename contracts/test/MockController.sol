// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import '../Epoch.sol';
import '../libraries/SafeMath.sol';
import '../libraries/UQ112x112.sol';
import '../interfaces/IUniswapOracle.sol';
import '../interfaces/IBurnableERC20.sol';

/**
 * NOTE: Contract ArthswapV1Pair should be the owner of this controller.
 */
contract MockController is Epoch {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /**
     * State variables.
     */

    // Token which will be used to charge penalty or reward incentives.
    IBurnableERC20 public token;

    // Used to track the latest twap price.
    IUniswapOracle public uniswapOracle;

    // Default price of when reward is to be given.
    uint256 public rewardPrice = uint256(120).mul(1e16); // ~1.2$
    // Default price of when penalty is to be charged.
    uint256 public penaltyPrice = uint256(95).mul(1e16); // ~0.95$

    // Should we use oracle to get diff. price feeds or not.
    bool public useOracle = false;

    // Max. reward per hour to be given out.
    uint256 public rewardPerHour = 13 * 1e18;

    uint256 public availableRewardThisHour = 0;
    uint256 public expectedVolumePerHour = 0;
    uint256 public currentVolumPerHour = 0;

    /**
     * Constructor.
     */
    constructor(uint256 startTime) public Epoch(60 * 60, startTime, 0) {}

    /**
     * Getters.
     */
    function _getOraclePrice() private view returns (uint256) {
        // try {
        //     return uniswapOracle.consult(protocolTokenAddress, 1e18);
        // } catch {
        //     revert('Controller: failed to consult cash price from the oracle');
        // }
    }

    // Given an output amount of an asset and pair reserves,
    // Returns a required input amount of the other asset.
    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256 amountIn) {
        require(amountOut > 0, 'Controller: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'Controller: INSUFFICIENT_LIQUIDITY');

        uint256 numerator = reserveIn.mul(amountOut).mul(1000);
        uint256 denominator = reserveOut.sub(amountOut).mul(997);

        amountIn = (numerator / denominator).add(1);
    }

    function getPenaltyPrice() public view returns (uint256) {
        // If (useOracle) then get penalty price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        if (!useOracle) return penaltyPrice;
        return _getOraclePrice();
    }

    function getRewardIncentivePrice() public view returns (uint256) {
        // If (useOracle) then get reward price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        if (!useOracle) return rewardPrice;
        return _getOraclePrice();
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
        return sellVolume.mul(deviationFromTarget).mul(percentOfPool).div(uint256(1e18).mul(1e18));
    }

    function estimateRewardToGive(uint256 buyVolume) public view returns (uint256) {
        return Math.min(buyVolume.mul(rewardPerHour).div(expectedVolumePerHour), availableRewardThisHour);
    }

    /**
     * Setters.
     */
    function setIncentiveToken(address newToken) public {
        require(newToken != address(0), 'Pair: invalid token');
        token = IBurnableERC20(newToken);
    }

    function setPenaltyPrice(uint256 newPenaltyPrice) public {
        penaltyPrice = newPenaltyPrice;
    }

    function setRewardPrice(uint256 newRewardPrice) public {
        rewardPrice = newRewardPrice;
    }

    function setMahaPerHour(uint256 _rewardPerHour) public {
        rewardPerHour = _rewardPerHour;
    }

    function setUniswapOracle(address newUniswapOracle) public {
        uniswapOracle = IUniswapOracle(newUniswapOracle);
    }

    function setUseOracle(bool isSet) public {
        useOracle = isSet;
    }

    function updateForEpoch() private checkEpoch {
        expectedVolumePerHour = currentVolumPerHour;
        availableRewardThisHour = rewardPerHour;
        currentVolumPerHour = 0;
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
            token.burnFrom(to, amountToBurn);
        }
    }

    function _incentiviseTrade(uint256 buyVolume, address to) private {
        // Calculate the amount as per volumne and rate.
        // Cap the amount to a maximum rewardPerHour if amount > maxRewardPerHour.
        uint256 amountToReward = Math.min(estimateRewardToGive(buyVolume), availableRewardThisHour);

        if (amountToReward > 0) {
            availableRewardThisHour = availableRewardThisHour.sub(amountToReward);

            // // Send reward to the appropriate address.
            token.transfer(to, amountToReward);
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
        uint256 priceALast,
        uint256 amountOutA,
        uint256 amountInA,
        address to
    ) public {
        _conductChecks(reserveA, priceALast, amountOutA, amountInA, to);
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
        if (canUpdate()) updateForEpoch();

        // Check if we are selling and if we are blow the target price?
        if (amountInA > 0) {
            // Check if we are below the targetPrice.
            uint256 penaltyTargetPrice = getPenaltyPrice();

            if (priceA < penaltyTargetPrice) {
                // is the user expecting some DAI? if so then this is a sell order
                // Calculate the amount of tokens sent.
                _penalizeTrade(priceA, penaltyTargetPrice, amountInA, reserveA, to);

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
