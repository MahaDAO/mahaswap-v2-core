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

    public uint256 expectedVolumePerHour = 10000 * 1e18;
    public uint256 mahaRewardPerHour = 13 * 1e18;

    /**
     * This is the function that burns the MAHA and returns how much ARTH should
     * actually be spent.
     *
     * Note we are always selling tokenA
     */
    function conductCheck(
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        address from,
        uint256 amountIn
    ) public virtual returns (uint256 amountA, uint256 amountB) {

        if (penatly) {


        // 1. get k value (= reserveA/reserveB)
        // 2. check if k < penaltyPrice
        // 3. check if action is sell (change arguments if u have to)
        // 4. burn maha if sell and based on the volume of the tx

        bool isValid = _checkIfValidTrade();
            if (!isValid) {
                // If invalid then charge penalty to the sender.

                if (address(penaltyToken) == address(token0)) {
                    penaltyToken.burnFrom(msg.sender, amount0Out);
                } else if (address(penaltyToken) == address(token1)) {
                    penaltyToken.burnFrom(msg.sender, amount1Out);
                } else {
                    // If token to be used for penalty is different then that of
                    // pair then we charge a specific amount of penalty.

                    uint256 maxBalance = penaltyToken.balanceOf(msg.sender);

                    // If balance is less than fee, then we charge the entire balance as penalty.
                    if (maxBalance < penaltyAmount) {
                        penaltyToken.burnFrom(msg.sender, maxBalance);
                    } else {
                        // Else, we charge the respective penalty amount.
                        penaltyToken.burnFrom(msg.sender, penaltyAmount);
                    }
                }

                return;
            }
        } else {
            // 1. get k value (= reserveA/reserveB)
            // 2. check if k > rewardPrice
            // 3. check if action is buy (change arguments if u have to)
            // 4. send maha stored in contract based on an hourly rate
            // 5. if we have 5000 MAHA for 30 days

            // depending on the volume, send maha to this tx and make sure we are under 13maha per hour
        }
    }
}
