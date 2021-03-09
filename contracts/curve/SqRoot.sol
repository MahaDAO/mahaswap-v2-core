// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import {Math} from '../libraries/Math.sol';
import {ICurve} from '../interfaces/ICurve.sol';

contract SqRootCurve is ICurve {
    function getCurvedDeviation(uint256 deviation) public view returns (uint256) {
        return Math.sqrt(deviation);
    }
}
