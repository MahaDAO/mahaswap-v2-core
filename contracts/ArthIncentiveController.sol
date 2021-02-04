// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/ICustomERC20.sol';
import './interfaces/ISimpleOracle.sol';
import './interfaces/IUniswapOracle.sol';
import './interfaces/IArthswapV1Factory.sol';
import './interfaces/IIncentiveController.sol';

/**
 * NOTE: Contract ArthswapV1Pair should be the owner of this controller.
 */
contract ArthIncentiveController is IIncentiveController, Ownable {
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
     * Modifier.
     */
    modifier onlyPair {
        require(msg.sender == pairAddress, 'Controller: Forbidden');
        _;
    }

    /**
     * Constructor.
     */
    constructor(address _pairAddress, address _protocolTokenAddress) public {
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
    ) public pure returns (uint256) {
        // % of pool = sellVolume / liquidity
        // % of deviation from target price = (tgt_price - price) / price
        // amountToburn = sellVolume * % of deviation from target price * % of pool * 100

        uint256 percentOfPool = sellVolume.div(liquidity).mul(1e18);
        uint256 deviationFromTarget = targetPrice.sub(price).div(targetPrice).mul(1e18);

        // NOTE: Shouldn't this be multiplied by 10000 instead of 100
        return sellVolume.mul(deviationFromTarget).mul(percentOfPool).mul(100).div(uint256(2).mul(1e18));
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
        uint256 liquidity = ICustomERC20(pairAddress).balanceOf(pairAddress);

        uint256 amountToBurn = estimatePenaltyToCharge(price, targetPrice, liquidity, sellVolume);

        if (amountToBurn > 0) {
            // NOTE: amount has to be approved from frontend.
            // Burn and charge penalty.
            token.burnFrom(penalized, amountToBurn);
        }
    }

    function _incentiviseTrade(
        uint256 price,
        uint256 amountOutA,
        uint256 buyVolume,
        address incentivized
    ) private {
        // if (amountRewardedThisHour >= availableRewardThisHour) return;

        // Calculate the rate for curr. period.
        uint256 rate = token.balanceOf(address(this)).mul(1e18).div(30).div(24);

        uint256 amountToReward = 0;
        // Calculate the amount as per volumne and rate.
        // Cap the amount to a maximum rewardPerHour if amount > maxRewardPerHour.
        amountToReward = rate.mul(buyVolume).mul(100).div(1e18);

        // amountToReward = Math.min(amountToReward, availableRewardThisHour.sub(amountRewardedThisHour));
        // amountRewardedThisHour = amountRewardedThisHour.add(amountRewardedThisHour);

        if (amountToReward > 0) {
            // Send reward to the appropriate address.
            token.transfer(incentivized, amountToReward);
        }
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
            _conductChecks(reserveA, reserveB, newReserveA, to, amountOutA, amountOutB);
        } else {
            _conductChecks(reserveB, reserveA, newReserveB, to, amountOutB, amountOutA);
        }
    }

    function _conductChecks(
        uint112 reserveA,
        uint112 reserveB,
        uint112 newReserveA,
        address to,
        uint256 amountOutA,
        uint256 amountOutB
    ) private {
        // update volume
        // TODO every hour, zero this out
        currentVolumPerHour = currentVolumPerHour.add(amountOutA);

        // Get the price for the token.
        uint256 price = uint256(UQ112x112.encode(reserveA).uqdiv(reserveB));

        // Check if we are below the targetPrice.
        if (price < getPenaltyPrice()) {
            // Check if we are selling.
            if (newReserveA < reserveA) {
                _penalizeTrade(price, amountOutA, amountOutB, to);
            }
        }

        if (price < getRewardIncentivePrice()) {
            // Check if we are buying.
            if (newReserveA > reserveA) {
                // If we are buying the main protocol token, then we incentivize the tx sender.
                _incentiviseTrade(price, amountOutA, amountOutB, to);
            }
        }
    }
}
