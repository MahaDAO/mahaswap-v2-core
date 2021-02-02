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
    uint256 rewardPrice;
    // Price of when penalty is to be charged.
    uint256 penaltyPrice;

    // Should we use oracle to get diff. price feeds or not.
    bool useOracle = false;

    uint256 public mahaRewardPerHour = 13 * 1e18;
    uint256 public expectedVolumePerHour = 10000 * 1e18;

    /**
     * Getters.
     */

    function _getCashPrice() private view returns (uint256) {
        // Verify that atleast token is ARTH token.
        require(
            IERC20(token0).name() == string('ARTH') || IERC20(token1).name() == string('ARTH'),
            'Pair: invalid pair'
        );

        // Get the arth token.
        address token = IERC20(token0).name() == 'ARTH' ? token0 : token1;

        try uniswapOracle.consult(token, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert('Controller: failed to consult cash price from the oracle');
        }
    }

    function _getGMUPrice() private view returns (uint256) {
        return gmuOracle.getPrice();
    }

    function getPenaltyPrice() view returns (uint256) {
        // If (useOracle) then get penalty price from an oracle
        // else get from a variable. this variable is settable from the factory.
        if (!useOracle) return penaltyPrice;

        return _getCashPrice();
    }

    function getRewardIncentivePrice() view returns (uint256) {
        // If (useOracle) then get reward price from an oracle
        // else get from a variable. this variable is settable from the factory.
        if (!useOracle) return rewardPrice;

        return _getCashPrice();
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
        uint256 priceToPayPenalty = getPenaltyPrice();
        if (priceA < priceToPayPenalty) {
            // If penalty is on then we burn penalty token.

            // 3. TODO: Check if action is sell.

            // 4-a. TODO: Based on the volumne of the tx figure out the amount to burn.
            uint256 amountToBurn = Math.min(amountIn, expectedVolumePerHour);

            // 4-b. Burn maha
            // NOTE: amount has to be approved from frontend.
            token.burnFrom(from, amountToBurn);

            // TODO: set approved amount to 0.

            return;
        }

        // 1. get k value (= reserveA/reserveB)
        // 2. check if k > rewardPrice
        // 3. check if action is buy (change arguments if u have to)
        // 4. send maha stored in contract based on an hourly rate
        // 5. if we have 5000 MAHA for 30 days
        // depending on the volume, send maha to this tx and make sure we are under 13maha per hour

        // 2. Check if k > rewardPrice.
        uint256 priceToGetReward = getRewardPrice();
        if (priceA > priceToGetReward) {
            // If reward is on then we transfer the rewards as per reward rate and tx volumne.

            // 3. TODO: Check if the action is to buy.

            // 4-a. TODO: Based on volumne, hourly rate and the max cap, figure out the amount to reward.
            uint25 amountToReward = 1e18;

            // 4-b. Send reward to the buyer.
            token.transfer(from, amountToReward);

            return;
        }
    }
}
