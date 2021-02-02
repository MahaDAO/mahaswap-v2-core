// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/ICustomERC20.sol';
import './interfaces/IUniswapV2Pair.sol';
import '../interfaces/ISimpleOracle.sol';
import '../interfaces/IUniswapOracle.sol';
import './UniswapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Callee.sol';

contract IncentiveController is IUniswapV2Pair, UniswapV2ERC20, Ownable {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /**
     * State variables.
     */

    // Token which will be used to charge penalty or reward incentives.
    ICustomERC20 token;
    // Oracle which will be used for  to track the latest target price.
    ISimpleOracle gmuOracle;
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
     * Getters.
     */

    function _getCashPrice(token) private view returns (uint256) {
        try uniswapOracle.consult(token, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert('Controller: failed to consult cash price from the oracle');
        }
    }

    function _getGMUPrice() private view returns (uint256) {
        return gmuOracle.getPrice();
    }

    function getPenaltyPrice(address tokenA) view returns (uint256) {
        // If (useOracle) then get penalty price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        if (!useOracle) return penaltyPrice;

        return _getCashPrice(tokenA);
    }

    function getRewardIncentivePrice(address tokenB) view returns (uint256) {
        // If (useOracle) then get reward price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        if (!useOracle) return rewardPrice;

        return _getCashPrice(tokenB);
    }

    /**
     * Setters.
     */

    function setToken(address newToken) public onlyOwner {
        require(newToken != address(0), 'Pair: invalid token');

        token = ICustomERC20(newToken);
    }

    function setPenaltyPrice(uint256 newPenaltyPrice) public onlyOwner {
        require(newPenaltyPrice > 0, 'Pair: invalid price');

        penaltyPrice = newPenaltyPrice;
    }

    function setRewardPrice(uint256 newRewardPrice) public onlyOwner {
        require(newRewardPrice > 0, 'Pair: invalid price');

        rewardPrice = newRewardPrice;
    }

    function setUniswapOracle(address newUniswapOracle) public onlyOwner {
        require(newUniswapOracle != address(0), 'Pair: invalid oracle');

        uniswapOracle = IUniswapOracle(newUniswapOracle);
    }

    function setGmuOracle(address newGmuOracle) public onlyOwner {
        require(newGmuOracle != address(0), 'Pair: invalid oracle');

        gmuOracle = ISimpleOracle(newGmuOracle);
    }

    /**
     * This is the function that burns the MAHA and returns how much ARTH should
     * actually be spent.
     *
     * Note we are always selling tokenA
     */
    function conductChecks(
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        address from,
        uint256 amountIn
    ) public virtual returns (uint256 amountA, uint256 amountB) {
        // 1. Get the k for A.
        uint256 priceA = uint256(UQ112x112.encode(reserveA).uqdiv(reserveB));

        // 2. Check if k < penaltyPrice.
        uint256 priceToPayPenalty = getPenaltyPrice(tokenA); // NOTE: we use tokenA since tokenA is always sell.
        if (priceA < priceToPayPenalty) {
            // If penalty is on then we burn penalty token.

            // 3. TODO: Check if action is sell.

            // 4-a. TODO: Based on the volumne of the tx figure out the amount to burn.
            uint256 amountToBurn = amountIn;

            // 4-b. Burn maha
            // NOTE: amount has to be approved from frontend.
            token.burnFrom(from, amountToBurn);

            // TODO: set approved amount to 0.

            return;
        }

        // 2. Check if k > rewardPrice.
        uint256 priceToGetReward = getRewardPrice(tokenB); // NOTE: we use tokenB since tokenA is always sell.
        if (priceA > priceToGetReward) {
            // If reward is on then we transfer the rewards as per reward rate and tx volumne.

            // 3. TODO: Check if the action is to buy.

            // 4-a. Based on volumne of the tx & hourly rate, figure out the amount to reward.
            uint256 rate = token.balanceOf(address(this)).div(30).div(24); // Calculate the rate for curr. period.
            uint25 amountToReward = rate.mul(amountIn);

            // 4-b. Cap the max reward.
            amountToReward = Math.min(amountToReward, mahaRewardPerHour);

            // 4-c. Send reward to the buyer.
            token.transfer(from, amountToReward);

            return;
        }
    }
}
