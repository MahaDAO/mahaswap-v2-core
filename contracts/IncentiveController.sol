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

/**
 * NOTE: Contract ArthswapV1Pair should be the owner of this controller.
 */
contract IncentiveController is Ownable {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /**
     * State variables.
     */

    // Token which will be used to charge penalty or reward incentives.
    ICustomERC20 public token;

    // Factory that will be using this contract.
    address public factoryAddress;
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

    uint256 public expectedVolumePerHour = 10000 * 1e18;

    /**
     * Modifiers
     */

    modifier onlyFactory {
        require(msg.sender == factoryAddress, 'Controller: Forbidden');

        _;
    }

    /**
     * Constructor.
     */
    constructor(address _factoryAddress, address _protocolTokenAddress) {
        factoryAddress = _factoryAddress;

        protocolTokenAddress = _protocolTokenAddress;
    }

    /**
     * Getters.
     */

    function _getTargetPrice() private view returns (uint256) {
        return gmuOracle.getPrice();
    }

    function _getCashPrice() private view returns (uint256) {
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

        return _getCashPrice();
    }

    function getRewardIncentivePrice() public view returns (uint256) {
        // If (useOracle) then get reward price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        if (!useOracle) return rewardPrice;

        return _getCashPrice();
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

    function setUseOracle(bool isSet) public onlyFactory {
        useOracle = isSet;
    }

    /**
     * Mutations.
     */

    function _checkAndPenalize(
        uint256 price,
        uint256 amountOutA,
        uint256 amountOutB,
        bool isTokenAProtocolToken,
        address from
    ) private {
        // The token which is the main protocol token and we are selling, then the other token should have
        // out amount > 0.
        require(isTokenAProtocolToken ? amountOutB > 0 : amountOutA > 0, 'Controller: invalid operation');

        // Get the penalty price
        uint256 penaltyTriggerPrice = getPenaltyPrice();

        // Check if we are below the penaltyPrice.
        if (price < penaltyTriggerPrice) {
            // If penalty is on then we penalize

            uint256 amountToBurn = 0;

            // Check if any amountOut is 0 or not.
            if (amountOutA > 0 && amountOutB > 0) {
                // If not then set amount to burn as per tx volume of which token is the protocol token.
                amountToBurn = isTokenAProtocolToken ? amountOutA : amountOutB;
            } else {
                // If any is 0, then we figure out the amount as per price.

                // If A is protocolToken, then amountOutB can not be 0 and vice versa.
                // However if amountOutProtocol is 0,
                // then we calculate the amount being sold as per price and amount of other token swapped.
                // Lets say A = 2$ and B = 1$, then A/B = 2/1 = 2.
                // Hence A = 2B.
                // Hence if we are selling A and outAmount is 0,
                // then we can calculate it with 2 * outAmountB.
                amountToBurn = (
                    penaltyTriggerPrice.sub(price).mul(isTokenAProtocolToken ? amountOutB : amountOutA).div(100)
                );
            }

            if (amountToBurn > 0) {
                // NOTE: amount has to be approved from frontend.
                // Burn and charge penalty.
                token.burnFrom(from, amountToBurn);
            }

            // TODO: set approved amount to 0.
        }
    }

    function _checkAndIncentivize(
        address to,
        uint256 price,
        uint256 amountOutA,
        uint256 amountOutB,
        bool isTokenAProtocolToken
    ) private {
        // The token which is the main protocol token and we are buying hence that token should have out amount > 0.
        require(isTokenAProtocolToken ? amountOutA > 0 : amountOutB > 0, 'Controller: invalid operation');

        // Check if we are above the reward price.
        // NOTE: can this be changed to price > getPenaltyPrice()?
        if (price > getRewardIncentivePrice()) {
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
                amountToReward = rate.mul(price.mul(isTokenAProtocolToken ? amountOutA : amountOutA));
            }

            // Calculate the amount as per volumne and rate.
            // Cap the amount to a maximum rewardPerHour if amount > maxRewardPerHour.
            amountToReward = Math.min(rate.mul(amountToReward), mahaRewardPerHour);

            if (amountToReward > 0) {
                // Send reward to the appropriate address.
                token.transfer(to, amountToReward);
            }
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
        address from,
        address to,
        uint256 amountOutA,
        uint256 amountOutB
    ) public virtual onlyOwner {
        require(tokenA == protocolTokenAddress || tokenB == protocolTokenAddress, 'Controller: invalid config');

        bool isTokenAProtocolToken = tokenA == protocolTokenAddress;

        // Get the price for the token.
        uint256 price =
            isTokenAProtocolToken
                ? uint256(UQ112x112.encode(reserveA).uqdiv(reserveB))
                : uint256(UQ112x112.encode(reserveB).uqdiv(reserveA));

        // Check if we are below the targetPrice.
        if (price < _getTargetPrice()) {
            // If we are below the target price, then we penalize or incentivize the tx sender.

            // Check if we are buying or selling.
            if (
                (isTokenAProtocolToken && newReserveA > reserveA) || (!isTokenAProtocolToken && newReserveB > reserveB)
            ) {
                // If we are buying the main protocol token, then we incentivize the tx sender.
                _checkAndIncentivize(to, price, amountOutA, amountOutB, isTokenAProtocolToken);
            } else {
                // Else we penalize the tx sender.
                _checkAndPenalize(price, amountOutA, amountOutB, isTokenAProtocolToken, from);
            }
        }
    }
}
