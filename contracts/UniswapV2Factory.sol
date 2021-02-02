// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/ICustomERC20.sol';
import '../interfaces/ISimpleOracle.sol';
import '../interfaces/IUniswapOracle.sol';
import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

contract UniswapV2Factory is IUniswapV2Factory, Ownable {
    address public feeTo;
    address public feeToSetter;

    // Token which will charge penalty.
    ICustomERC20 public penaltyToken;
    // Token which will be used for rewards.
    ICustomERC20 public rewardToken;

    // Token which will be used for  to track the latest target price.
    ISimpleOracle gmuOracle;
    // Used to track the latest twap price.
    IUniswapOracle uniswapOracle;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    constructor(
        address _feeToSetter,
        address _penaltyToken,
        address _rewardToken,
        address _gmuOracle,
        address _uniswapOracle
    ) public {
        feeToSetter = _feeToSetter;

        penaltyToken = ICustomERC20(_penaltyToken);
        rewardToken = ICustomERC20(_rewardToken);

        gmuOracle = ISimpleOracle(_gmuOracle);
        uniswapOracle = IUniswapOracle(_uniswapOracle);
    }

    function setGmuOracle(address newGmuOracle) public onlyOwner {
        require(newGmuOracle != address(0), 'Pair: invalid oracle');

        gmuOracle = ISimpleOracle(newGmuOracle);
    }

    function setUniswapOracle(address newUniswapOracle) public onlyOwner {
        require(newUniswapOracle != address(0), 'Pair: invalid oracle');

        uniswapOracle = IUniswapOracle(newUniswapOracle);
    }

    function setPenaltyToken(address newPenaltyToken) public onlyOwner {
        require(newUniswapOracle != address(0), 'Pair: invalid token');

        penaltyToken = ICustomERC20(newPenaltyToken);
    }

    function setRewardToken(address newRewardToken) public onlyOwner {
        require(newRewardToken != address(0), 'Pair: invalid token');

        rewardToken = ICustomERC20(newRewardToken);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IUniswapV2Pair(pair).initialize(
            token0,
            token1,
            address(penaltyToken),
            address(rewardToken),
            address(gmuOracle),
            address(uniswapOracle)
        );

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter || msg.sender == owner(), 'UniswapV2: FORBIDDEN');

        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');

        feeToSetter = _feeToSetter;
    }
}
