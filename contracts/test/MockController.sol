// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import '../Epoch.sol';
import '../libraries/SafeMath.sol';
import '../libraries/UQ112x112.sol';
import '../interfaces/IUniswapOracle.sol';
import '../interfaces/IBurnableERC20.sol';

/**
 * NOTE: Contract MahaswapV1Pair should be the owner of this controller.
 */
contract MockController is Epoch {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /**
     * State variables.
     */

    // Token which will be used to charge penalty or reward incentives.
    IBurnableERC20 public incentiveToken;

    // A fraction of penalty is being used to fund the ecosystem.
    address ecosystemFund;

    // Used to track the latest twap price.
    IUniswapOracle public uniswapOracle;

    // Default price of when reward is to be given.
    uint256 public rewardPrice = uint256(110).mul(1e16); // ~1.2$
    // Default price of when penalty is to be charged.
    uint256 public penaltyPrice = uint256(110).mul(1e16); // ~0.95$

    // Should we use oracle to get diff. price feeds or not.
    bool public useOracle = false;

    // Multipiler for rewards and penalty.
    uint256 public rewardMultiplier = 100000;
    uint256 public penaltyMultiplier = 100000;

    // Percentage of penalty to be burnt from the token's supply.
    uint256 public penaltyToBurn = uint256(45); // In %.
    // Percentage of penalty to be kept inside this contract to act as fund for rewards.
    uint256 public penaltyToKeep = uint256(45); // In %.
    // Percentage of penalty to be redirected to diff. funds(currently ecosystem fund).
    uint256 public penaltyToRedirect = uint256(10); // In %.

    // Max. reward per hour to be given out.
    uint256 public rewardPerEpoch = 0;

    uint256 arthToMahaRate = 1 * 1e18;

    uint256 public availableRewardThisEpoch = 0;

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
        uint256 liquidity,
        uint256 sellVolume
    ) public view returns (uint256) {
        uint256 targetPrice = getPenaltyPrice();

        // % of pool = sellVolume / liquidity
        // % of deviation from target price = (tgt_price - price) / price
        // amountToburn = sellVolume * % of deviation from target price * % of pool * 100
        if (price >= targetPrice) return 0;

        uint256 percentOfPool = sellVolume.mul(10000).div(liquidity);
        uint256 deviationFromTarget = targetPrice.sub(price).mul(10000).div(targetPrice);

        // A number from 0-100%.
        uint256 feeToCharge = Math.max(percentOfPool, deviationFromTarget);

        // NOTE: Shouldn't this be multiplied by 10000 instead of 100
        // NOTE: multiplication by 100, is removed in the mock controller
        // Can 2x, 3x, ... the penalty.
        return sellVolume.mul(feeToCharge).mul(arthToMahaRate).mul(penaltyMultiplier).div(10000 * 100000 * 1e18);
    }

    function estimateRewardToGive(
        uint256 price,
        uint256 liquidity,
        uint256 buyVolume
    ) public view returns (uint256) {
        uint256 targetPrice = getRewardIncentivePrice();

        // % of pool = buyVolume / liquidity
        // % of deviation from target price = (tgt_price - price) / price
        // rewardToGive = buyVolume * % of deviation from target price * % of pool * 100
        if (price >= targetPrice) return 0;

        uint256 percentOfPool = buyVolume.mul(10000).div(liquidity);
        uint256 deviationFromTarget = targetPrice.sub(price).mul(10000).div(targetPrice);

        // A number from 0-100%.
        uint256 rewardToGive = Math.min(percentOfPool, deviationFromTarget);

        uint256 calculatedRewards =
            buyVolume.mul(rewardToGive).mul(arthToMahaRate).mul(rewardMultiplier).div(10000 * 100000 * 1e18);

        return Math.min(availableRewardThisEpoch, calculatedRewards);
    }

    /**
     * Setters.
     */

    function setPenaltyToBurn(uint256 percent) public onlyOwner {
        require(percent > 0 && percent < 100, 'Controller: invalid %');

        penaltyToBurn = percent;
    }

    function setPenaltyToRedirect(uint256 percent) public onlyOwner {
        require(percent > 0 && percent < 100, 'Controller: invalid %');

        penaltyToRedirect = percent;
    }

    function setPenaltyToKeep(uint256 percent) public onlyOwner {
        require(percent > 0 && percent < 100, 'Controller: invalid %');

        penaltyToKeep = percent;
    }

    function setEcosystemFund(address fund) external onlyOwner {
        ecosystemFund = fund;
    }

    function setRewardMultiplier(uint256 multiplier) public onlyOwner {
        rewardMultiplier = multiplier;
    }

    function setPenaltyMultiplier(uint256 multiplier) public onlyOwner {
        penaltyMultiplier = multiplier;
    }

    function setArthToMahaRate(uint256 rate) public {
        arthToMahaRate = rate;
    }

    function setIncentiveToken(address newToken) public {
        require(newToken != address(0), 'Pair: invalid token');
        incentiveToken = IBurnableERC20(newToken);
    }

    function setPenaltyPrice(uint256 newPenaltyPrice) public {
        penaltyPrice = newPenaltyPrice;
    }

    function setRewardPrice(uint256 newRewardPrice) public {
        rewardPrice = newRewardPrice;
    }

    function setMahaPerEpoch(uint256 _rewardPerEpoch) public {
        rewardPerEpoch = _rewardPerEpoch;
    }

    function setUniswapOracle(address newUniswapOracle) public {
        uniswapOracle = IUniswapOracle(newUniswapOracle);
    }

    function setUseOracle(bool isSet) public {
        useOracle = isSet;
    }

    function _updateForEpoch() private {
        availableRewardThisEpoch = rewardPerEpoch;
        lastExecutedAt = block.timestamp;
    }

    function refundIncentiveToken() external onlyOwner {
        incentiveToken.transfer(msg.sender, incentiveToken.balanceOf(address(this)));
    }

    /**
     * Mutations.
     */
    function _penalizeTrade(
        uint256 price,
        uint256 sellVolume,
        uint256 liquidity,
        address to
    ) private {
        uint256 amountToPenalize = estimatePenaltyToCharge(price, liquidity, sellVolume);

        if (amountToPenalize > 0) {
            // NOTE: amount has to be approved from frontend.

            // Burn and charge a fraction of the penalty.
            incentiveToken.burnFrom(to, amountToPenalize.mul(penaltyToBurn).div(100));

            // Keep a fraction of the penalty as funds for paying out rewards.
            incentiveToken.transferFrom(to, address(this), amountToPenalize.mul(penaltyToKeep).div(100));

            // Send a fraction of the penalty to fund the ecosystem.
            incentiveToken.transferFrom(to, ecosystemFund, amountToPenalize.mul(penaltyToRedirect).div(100));
        }
    }

    function _incentiviseTrade(
        uint256 price,
        uint256 buyVolume,
        uint256 liquidity,
        address to
    ) private {
        // Calculate the amount as per volumne and rate.
        uint256 amountToReward = estimateRewardToGive(price, liquidity, buyVolume);

        if (amountToReward > 0) {
            availableRewardThisEpoch = availableRewardThisEpoch.sub(amountToReward);

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
        uint256 price,
        uint256 amountOutA,
        uint256 amountInA,
        address to
    ) external {
        _conductChecks(reserveA, price, amountOutA, amountInA, to);
    }

    function _conductChecks(
        uint112 reserveA, // ARTH liquidity
        uint256 priceA, // ARTH price
        uint256 amountOutA, // ARTH being bought
        uint256 amountInA, // ARTH being sold
        address to
    ) private {
        // capture volume and snapshot it every epoch.
        if (getCurrentEpoch() >= getNextEpoch()) _updateForEpoch();

        // Check if we are selling and if we are blow the target price?
        if (amountInA > 0) {
            // Check if we are below the targetPrice.
            uint256 penaltyTargetPrice = getPenaltyPrice();

            if (priceA < penaltyTargetPrice) {
                // is the user expecting some DAI? if so then this is a sell order
                // Calculate the amount of tokens sent.
                _penalizeTrade(priceA, amountInA, reserveA, to);

                // stop here to save gas
                return;
            }
        }

        // Check if we are buying and below the target price
        if (amountOutA > 0 && priceA < getRewardIncentivePrice() && availableRewardThisEpoch > 0) {
            // is the user expecting some ARTH? if so then this is a sell order
            // If we are buying the main protocol token, then we incentivize the tx sender.
            _incentiviseTrade(priceA, amountOutA, reserveA, to);
        }
    }
}
