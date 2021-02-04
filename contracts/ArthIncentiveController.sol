// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/ICustomERC20.sol';
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
    ICustomERC20 public token;

    // Pair that will be using this contract.
    address public pairAddress;

    // Token which is the main token of a protocol.
    address public protocolTokenAddress;

    // Used to track targetPrice.
    ISimpleOracle public gmuOracle;

    // Used to track the latest twap price.
    IUniswapOracle public uniswapOracle;

    // Default price of when reward is to be given.
    uint256 public rewardPrice = uint256(120).mul(1e16); // ~1.2$
    // Default price of when penalty is to be charged.
    uint256 public penaltyPrice = uint256(95).mul(1e16); // ~0.95$

    // Should we use oracle to get diff. price feeds or not.
    bool public useOracle = false;

    // Max. reward per hour to be given out.
    uint256 public mahaRewardPerHour = 13 * 1e18;

    uint256 public expectedVolumePerHour = 0;
    uint256 public currentVolumPerHour = 0;

    /**
     * Modifiers
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
        try uniswapOracle.consult(protocolTokenAddress, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert('Controller: failed to consult cash price from the oracle');
        }
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
    ) public view returns (uint256) {
        // % of pool = sellVolume / liquidity
        // % of deviation from target price = (tgt_price - price) / price
        // amountToburn = sellVolume * % of deviation from target price * % of pool * 100

        return 0;
    }

    /**
     * Setters.
     */
    function setIncentiveToken(address newToken) public onlyOwner {
        require(newToken != address(0), 'Pair: invalid token');
        token = ICustomERC20(newToken);
    }

    function setPenaltyPrice(uint256 newPenaltyPrice) public onlyOwner {
        penaltyPrice = newPenaltyPrice;
    }

    function setRewardPrice(uint256 newRewardPrice) public onlyOwner {
        rewardPrice = newRewardPrice;
    }

    function setUniswapOracle(address newUniswapOracle) public onlyOwner {
        uniswapOracle = IUniswapOracle(newUniswapOracle);
    }

    function setUseOracle(bool isSet) public onlyOwner {
        useOracle = isSet;
    }

    function updateForEpoch() private checkEpoch returns (bool feeOn) {
        expectedVolumePerHour = currentVolumPerHour;
        amountRewardedThisHour = 0;
        mahaRewardPerHour = 13;
        currentVolumPerHour = 0;
    }

    /**
     * Mutations.
     */
    function _penalizeTrade(
        uint256 tradingPrice,
        uint256 amountOutA,
        uint256 amountOutB,
        address from
    ) private {
        // Get the target price
        uint256 targetPrice = 0;

        uint256 amountToBurn = estimatePenaltyToCharge(tradingPrice, targetPrice, reserve0);

        if (amountToBurn > 0) {
            // NOTE: amount has to be approved from frontend.
            // Burn and charge penalty.
            token.burnFrom(from, amountToBurn);
        }
    }

    function _incentiviseTrade(
        uint256 price,
        uint256 amountOutA,
        uint256 amountOutB,
        address from
    ) private {
        // Check if we are above the reward price.
        // NOTE: can this be changed to price > getPenaltyPrice()?

        // If reward is on then we reward.

        // Based on volumne of the tx & hourly rate, figure out the amount to reward.
        uint256 rate = token.balanceOf(address(this)).div(30).div(24); // Calculate the rate for curr. period.

        uint256 amountToReward = 0;

        // Check if any amount is 0 or not.
        if (amountOutA > 0 && amountOutB > 0) {
            // If not, then set the amount as per the rate and volume of the protocol token.
            amountToReward = isTokenAProtocolToken ? amountOutA : amountOutB;
        } else {
            // If any is 0, then we figure out which one is 0.

            // If A is protocolToken, then amountOutA can not be 0 and vice versa.
            // However if the other token out amount is 0,
            // then we calculate the amount being sold as per price and amount of the protocolToken.
            // Refer Line 165 to 168.
            amountToReward = rate.mul(price.mul(amountOutA));
        }

        // Calculate the amount as per volumne and rate.
        // Cap the amount to a maximum rewardPerHour if amount > maxRewardPerHour.
        amountToReward = Math.min(rate.mul(amountToReward), mahaRewardPerHour);
        amountRewardedThisHour = amountRewardedThisHour.add(amountRewardedThisHour);

        // if (kjh >= availableMahaThisHour) return;

        // if (amountToReward > 0) {
        //     // Send reward to the appropriate address.
        //     token.transfer(to, amountToReward);
        // }
    }

    /**
     * This is the function that burns the MAHA and returns how much ARTH should
     * actually be spent.
     *
     * Note we are always selling tokenA.
     */
    function conductChecks(
        address tokenA,
        address tokenB,
        uint112 reserveA,
        uint112 reserveB,
        uint112 newReserveA,
        uint112 newReserveB,
        address to,
        uint256 amountOutA,
        uint256 amountOutB
    ) public virtual override onlyPair {
        require(tokenA == protocolTokenAddress || tokenB == protocolTokenAddress, 'Controller: invalid config');
        bool isTokenAProtocolToken = tokenA == protocolTokenAddress;

        if (isTokenAProtocolToken) {
            _conductChecks(tokenA, tokenB, reserveA, reserveB, newReserveA, newReserveB, to, amountOutA, amountOutB);
        } else {
            _conductChecks(tokenB, tokenA, reserveB, reserveA, newReserveB, newReserveA, to, amountOutB, amountOutA);
        }
    }

    function _conductChecks(
        address tokenA,
        address tokenB,
        uint112 reserveA,
        uint112 reserveB,
        uint112 newReserveA,
        uint112 newReserveB,
        address to,
        uint256 amountOutA,
        uint256 amountOutB
    ) private {
        // update volume
        // TODO every hour, zero this out
        currentVolumPerHour = currentVolumPerHour.add(amountOutA);

        if (canUpdate()) updateForEpoch();

        // Get the price for the token.
        uint256 price = uint256(UQ112x112.encode(reserveA).uqdiv(reserveB));

        // Check if we are below the targetPrice.
        if (price < getPenaltyPrice()) {
            // Check if we are selling.
            if ((newReserveA < reserveA) && (newReserveB || reserveB)) {
                _penalizeTrade(price, amountOutA, amountOutB, to);
            }
        }

        if (price < getRewardIncentivePrice()) {
            // Check if we are buying
            if ((newReserveA > reserveA) || (newReserveB > reserveB)) {
                // If we are buying the main protocol token, then we incentivize the tx sender.
                _incentiviseTrade(price, amountOutA, amountOutB, to);
            }
        }
    }
}
