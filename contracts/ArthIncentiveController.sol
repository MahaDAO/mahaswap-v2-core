// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import './libraries/SafeMath.sol';
import './libraries/Ownable.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IBurnableERC20.sol';
import './interfaces/ISimpleOracle.sol';
import './interfaces/IUniswapOracle.sol';
import './interfaces/IArthswapV1Factory.sol';
import './interfaces/IIncentiveController.sol';
import './Epoch.sol';

/**
 * NOTE: Contract ArthswapV1Pair should be the owner of this controller.
 */
contract ArthIncentiveController is IIncentiveController, Epoch {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /**
     * State variables.
     */

    // Token which will be used to charge penalty or reward incentives.
    IBurnableERC20 public token;

    // Pair that will be using this contract.
    address public pairAddress;

    // Token which is the main token of a protocol.
    address public protocolTokenAddress;

    // Used to track the latest twap price.
    IUniswapOracle public uniswapOracle;

    // Default price of when reward is to be given.
    uint256 public rewardPrice = uint256(120).mul(1e16); // ~1.2$
    // Default price of when penalty is to be charged.
    uint256 public penaltyPrice = uint256(95).mul(1e16); // ~0.95$

    // Should we use oracle to get diff. price feeds or not.
    bool public useOracle = false;

    bool public isTokenAProtocolToken = true;

    // Max. reward per hour to be given out.
    uint256 public rewardPerHour = 13 * 1e18;

    uint256 public availableRewardThisHour = 0;
    uint256 public expectedVolumePerHour = 0;
    uint256 public currentVolumPerHour = 0;

    /**
     * Modifier.
     */
    modifier onlyPair {
        require(msg.sender == pairAddress, 'Controller: Forbidden');
        _;
    }

    /**
     * Constructor.
     */
    constructor(
        address _pairAddress,
        address _protocolTokenAddress,
        uint256 startTime
    ) public Epoch(60 * 60, startTime, 0) {
        pairAddress = _pairAddress;
        protocolTokenAddress = _protocolTokenAddress;
    }

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

        uint256 percentOfPool = sellVolume.div(liquidity).mul(1e18);
        uint256 deviationFromTarget = targetPrice.sub(price).div(targetPrice).mul(1e18);

        // NOTE: Shouldn't this be multiplied by 10000 instead of 100
        return sellVolume.mul(deviationFromTarget).mul(percentOfPool).mul(100).div(uint256(2).mul(1e18));
    }

    function estimateRewardToGive(uint256 buyVolume) public view returns (uint256) {
        return Math.min(buyVolume.mul(rewardPerHour).div(expectedVolumePerHour), availableRewardThisHour);
    }

    /**
     * Setters.
     */
    function setIncentiveToken(address newToken) public onlyOwner {
        require(newToken != address(0), 'Pair: invalid token');
        token = IBurnableERC20(newToken);
    }

    function setPenaltyPrice(uint256 newPenaltyPrice) public onlyOwner {
        penaltyPrice = newPenaltyPrice;
    }

    function setRewardPrice(uint256 newRewardPrice) public onlyOwner {
        rewardPrice = newRewardPrice;
    }

    function setMahaPerHour(uint256 _rewardPerHour) public onlyOwner {
        rewardPerHour = _rewardPerHour;
    }

    function setUniswapOracle(address newUniswapOracle) public onlyOwner {
        uniswapOracle = IUniswapOracle(newUniswapOracle);
    }

    function setUseOracle(bool isSet) public onlyOwner {
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
        address penalized
    ) private {
        // TODO: calculate liquidity provided by token in pool.
        uint256 liquidity = IBurnableERC20(pairAddress).balanceOf(pairAddress);

        uint256 amountToBurn = estimatePenaltyToCharge(price, targetPrice, liquidity, sellVolume);

        if (amountToBurn > 0) {
            // NOTE: amount has to be approved from frontend.
            // Burn and charge penalty.
            token.burnFrom(penalized, amountToBurn);
        }
    }

    function _incentiviseTrade(uint256 buyVolume, address to) private {
        // if (amountRewardedThisHour >= availableRewardThisHour) return;

        // Calculate the rate for curr. period.
        // uint256 rate = token.balanceOf(address(this)).mul(1e18).div(30).div(24);

        // Calculate the amount as per volumne and rate.
        // Cap the amount to a maximum rewardPerHour if amount > maxRewardPerHour.
        uint256 amountToReward = Math.min(estimateRewardToGive(buyVolume), availableRewardThisHour);

        if (amountToReward > 0) {
            availableRewardThisHour = availableRewardThisHour.sub(amountToReward);

            // Send reward to the appropriate address.
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
        uint256 amountInA,
        uint256 amountInB,
        uint256 amountOutA,
        uint256 amountOutB,
        address to
    ) public onlyPair {
        // require(tokenA == protocolTokenAddress || tokenB == protocolTokenAddress, 'Controller: invalid config');
        // uint112 amountOutA = 0;
        // uint112 amountOutB = 0;
        // if (isTokenAProtocolToken) {
        //     _conductChecks(reserveA, reserveB, newReserveA, to, amountOutA, amountOutB);
        // } else {
        //     _conductChecks(reserveB, reserveA, newReserveB, to, amountOutB, amountOutA);
        // }
    }

    function _conductChecks(
        uint112 reserveA, // A is always the token we are buying or selling.
        uint112 reserveB,
        uint112 newReserveA,
        address to,
        uint256 amountOutA, // The output amount for buy and sell token.
        uint256 amountOutB
    ) private {
        // update volume
        // TODO every hour, zero this out
        currentVolumPerHour = currentVolumPerHour.add(amountOutA);

        if (canUpdate()) updateForEpoch();

        // Get the price for the token.
        uint256 price = uint256(UQ112x112.encode(reserveA).uqdiv(reserveB));

        // Check if we are below the targetPrice.
        uint256 penaltyTargetPrice = getPenaltyPrice();
        if (price < penaltyTargetPrice) {
            // Check if we are selling.
            if (newReserveA < reserveA) {
                // Calculate the amount of tokens sent.
                _penalizeTrade(price, penaltyTargetPrice, _getAmountIn(amountOutB, reserveA, reserveB), to);
            }
        }

        if (price < getRewardIncentivePrice()) {
            // Check if we are buying.
            if (newReserveA > reserveA) {
                // If we are buying the main protocol token, then we incentivize the tx sender.
                _incentiviseTrade(amountOutA, to);
            }
        }
    }
}
