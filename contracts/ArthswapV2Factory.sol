// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import '@openzeppelin/contracts/access/Ownable.sol';

import './UniswapV2Pair.sol';
import './ArthswapV2Pair.sol';
import './interfaces/ICustomERC20.sol';
import '../interfaces/ISimpleOracle.sol';
import '../interfaces/IUniswapOracle.sol';
import './interfaces/IUniswapV2Factory.sol';

contract ArthswapV2Factory is IUniswapV2Factory, Ownable {
    /**
     * State variables.
     */

    address public feeTo;
    // Who can set the feeTo.
    address public feeToSetter;

    // Default uniswap factory for pairs that are not arth & dai.
    IUniswapV2Factory defaultFactory;

    // Token which will be used for rewards.
    ICustomERC20 public rewardToken;
    // Token which will charge penalty.
    ICustomERC20 public penaltyToken;

    // Token which will be used for  to track the latest target price.
    ISimpleOracle gmuOracle;
    // Used to track the latest twap price.
    IUniswapOracle uniswapOracle;

    address[] public allPairs;
    mapping(address => mapping(address => address)) public _getPair;

    /**
     * Event.
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    /**
     * Constructor.
     */
    constructor(address _defaultFactory, address _feeToSetter) public {
        defaultFactory = IUniswapV2Factory(_defaultFactory);

        feeToSetter = _feeToSetter;
    }

    /**
     * Getter.
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function _getPairMode(address token0, address token1) private view returns (uint256) {
        if (
            (token0 == arthTokenAddress && token1 == daiTokenAddress) ||
            (token0 == daiTokenAddress && token1 == arthTokenAddress)
        ) {
            return uint256(1);
        }

        return uint256(0);
    }

    function getPair(address token0, address token1) public returns (address) {
        if (_getPair[token0][token1] == address(0)) {
            return defaultFactory.getPair(token0, token1);
        }

        return _getPair[token0][token1];
    }

    /**
     * Mutations.
     */

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(_getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient

        // Check if the tokens form a pair of ARTH/DAI.
        uint256 mode = _getPairMode(tokenA, tokenB);

        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IUniswapV2Pair(pair).initialize(token0, token1);

        _getPair[token0][token1] = pair;
        _getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    // todo check this yash
    function setIncentiveControllerForPair(
        address token0,
        address token1,
        address addr
    ) onlyOwner {
        address pair = _getPair[token1][token0];
        IUniswapV2Pair(pair).setIncentiveController(addr);
    }
}
