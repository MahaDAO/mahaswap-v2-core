// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import {ICurve} from '../interfaces/ICurve.sol';
import {SafeMath} from '../libraries/SafeMath.sol';

contract CubicCurve is ICurve {
    using SafeMath for uint256;

    function getCurvedDeviation(uint256 deviation) public view returns (uint256) {
        return deviation.mul(deviation).mul(deviation).div(1e18).div(1e18);
    }
}
