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

    uint256 public mahaRewardPerHour = 13 * 1e18;
    uint256 public expectedVolumePerHour = 10000 * 1e18;

    // Price of when penalty is to be charged.
    uint256 penaltyPrice;
    // Price of when reward is to be given.
    uint256 rewardPrice;

    // Token which will be used to charge penalty or reward incentives.
    ICustomERC20 token;
    // Oracle which will be used for  to track the latest target price.
    ISimpleOracle gmuOracle;
    // Used to track the latest twap price.
    IUniswapOracle uniswapOracle;

    /**
     * Getters.
     */

    function _getGMUPrice() private view returns (uint256) {
        return gmuOracle.getPrice();
    }

    function getPenaltyPrice() view returns (uint256) {
        // if (useOracle) then get penalty price from an oracle
        // else get from a variable; this variable is settable from the

        // allow useOracle & the oracle to be set by the factory class
        return 1e16 * 95;
    }

    function getRewardIncentivePrice() view returns (uint256) {
        return 1e16 * 120;
    }

    /**
     * Setters.
     */

    function setToken(address newToken) public onlyOwner {
        require(newToken != address(0), 'Pair: invalid token');

        token = ICustomERC20(newToken);
    }

    function setPenaltyPrice(uint256 newPenaltyPrice) public onlyOwner {
        require(newPenaltyPrice > 0, 'Pair: invalid token');

        penaltyPrice = newPenaltyPrice;
    }

    function setRewardPrice(uint256 newRewardPrice) public onlyOwner {
        require(newRewardPrice > 0, 'Pair: invalid token');

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

    function _getCashPrice() private view returns (uint256) {
        require(
            IERC20(token0).name() == string('ARTH') || IERC20(token1).name() == string('ARTH'),
            'Pair: invalid pair'
        );

        // Get the arth token.
        address token = IERC20(token0).name() == 'ARTH' ? token0 : token1;

        try uniswapOracle.consult(token, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert('Treasury: failed to consult cash price from the oracle');
        }
    }

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
