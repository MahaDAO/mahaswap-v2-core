// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/ICustomERC20.sol';
import './interfaces/ISimpleOracle.sol';
import './interfaces/IUniswapOracle.sol';
import './interfaces/IArthswapV1Factory.sol';

contract IncentiveController {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /**
     * State variables.
     */

    // Factory that will be using this contract.
    IArthswapV1Factory factory;

    // Token which will be used to charge penalty or reward incentives.
    ICustomERC20 token;

    // // Oracle which will be used for  to track the latest target price.
    // ISimpleOracle gmuOracle;

    // Used to track the latest twap price.
    IUniswapOracle uniswapOracle;

    // Price of when reward is to be given.
    uint256 rewardPrice = uint256(120).mul(1e16); // ~1.2$
    // Price of when penalty is to be charged.
    uint256 penaltyPrice = uint256(95).mul(1e16); // ~0.95$

    // Should we use oracle to get diff. price feeds or not.
    bool useOracle = false;

    uint256 public mahaRewardPerHour = 13 * 1e18;
    uint256 public expectedVolumePerHour = 10000 * 1e18;

    /**
     * Modifiers
     */

    modifier onlyFactory {
        require(msg.sender == address(factory), 'Controller: Forbidden');

        _;
    }

    modifier onlyPair(address tokenA, address tokenB) {
        require(msg.sender == factory.getPair(tokenA, tokenB), 'Controller: forbidden');

        _;
    }

    /**
     * Constructor.
     */
    constructor(address _factory) {
        factory = IArthswapV1Factory(_factory);
    }

    /**
     * Getters.
     */

    function _getCashPrice(token) private view returns (uint256) {
        try uniswapOracle.consult(token, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert('Controller: failed to consult cash price from the oracle');
        }
    }

    // function _getGMUPrice() private view returns (uint256) {
    //     return gmuOracle.getPrice();
    // }

    function getPenaltyPrice(address tokenA) view returns (uint256) {
        // If (useOracle) then get penalty price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        if (!useOracle) return penaltyPrice;

        return _getCashPrice(tokenA);
    }

    function getRewardIncentivePrice(address tokenA) view returns (uint256) {
        // If (useOracle) then get reward price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        if (!useOracle) return rewardPrice;

        return _getCashPrice(tokenA);
    }

    /**
     * Setters.
     */

    function setToken(address newToken) public onlyFactory {
        require(newToken != address(0), 'Pair: invalid token');

        token = ICustomERC20(newToken);
    }

    function setPenaltyPrice(uint256 newPenaltyPrice) public onlyFactory {
        require(newPenaltyPrice > 0, 'Pair: invalid price');

        penaltyPrice = newPenaltyPrice;
    }

    function setRewardPrice(uint256 newRewardPrice) public onlyFactory {
        require(newRewardPrice > 0, 'Pair: invalid price');

        rewardPrice = newRewardPrice;
    }

    function setUniswapOracle(address newUniswapOracle) public onlyFactory {
        require(newUniswapOracle != address(0), 'Pair: invalid oracle');

        uniswapOracle = IUniswapOracle(newUniswapOracle);
    }

    // function setGmuOracle(address newGmuOracle) public onlyFactory {
    //     require(newGmuOracle != address(0), 'Pair: invalid oracle');

    //     gmuOracle = ISimpleOracle(newGmuOracle);
    // }

    /**
     * This is the function that burns the MAHA and returns how much ARTH should
     * actually be spent.
     *
     * Note we are always selling tokenA
     */
    // This function should not be public, only pair/factory should be able to access it.
    function conductChecks(
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        address from,
        uint256 amountA,
        uint256 amountB
    ) public virtual onlyPair(tokenA, tokenB) {
        // 1. Get the k for A in terms of B.
        uint256 priceA = uint256(UQ112x112.encode(reserveA).uqdiv(reserveB));

        // 2. Check if k < penaltyPrice.
        uint256 priceToPayPenalty = getPenaltyPrice(tokenA);
        if (priceA < priceToPayPenalty) {
            // If penalty is on then we burn penalty token.

            // 3. Check if action is sell.
            require(amountA == 0 && amountB > 0, 'Controller: This is not sell tx');

            // 4-a. Get amount of A we are selling as per the current price.
            uint256 amountToBurn = priceA.mul(uint256(amountB));

            // 4-b. Burn maha, based on the volumne of the tx figure out the amount to burn.
            // NOTE: amount has to be approved from frontend.
            token.burnFrom(from, amountToBurn);

            // TODO: set approved amount to 0.

            return;
        }

        // 2. Check if k > rewardPrice.
        uint256 priceToGetReward = getRewardPrice(tokenA);
        if (priceA > priceToGetReward) {
            // If reward is on then we transfer the rewards as per reward rate and tx volumne.

            // 3. Check if the action is to buy.
            require(amountA > 0 && amountB >= 0, 'Controller: This is not buy tx');

            // 4-a. Based on volumne of the tx & hourly rate, figure out the amount to reward.
            uint256 rate = token.balanceOf(address(this)).div(30).div(24); // Calculate the rate for curr. period.

            // Get amount of A we are buying
            uint25 amountToReward = rate.mul(amountA);

            // 4-b. Cap the max reward.
            amountToReward = Math.min(amountToReward, mahaRewardPerHour);

            // 4-c. Send reward to the buyer.
            token.transfer(from, amountToReward);

            return;
        }
    }
}
