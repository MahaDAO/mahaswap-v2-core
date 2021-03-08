// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import {State} from './State.sol';

/**
 * NOTE: Contract MahaswapV1Pair should be the owner of this controller.
 */
contract Getters is State {
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

    function getLatestQuoteInUSD() public view returns (uint256) {
        uint256 decimalUsed = priceFeed.decimals();
        uint256 decimalDiff = uint256(18).sub(decimalUsed);

        (uint80 roundID, int256 price, uint256 startedAt, uint256 timeStamp, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        if (decimalDiff > 0) return uint256(price).mul(uint256(10**decimalDiff));
        return uint256(price);
    }

    function getPenaltyPrice() public view returns (uint256) {
        // If (useOracle) then get penalty price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        return penaltyPrice;
    }

    function getRewardIncentivePrice() public view returns (uint256) {
        // If (useOracle) then get reward price from an oracle
        // else get from a variable.
        // This variable is settable from the factory.
        return rewardPrice;
    }
}
