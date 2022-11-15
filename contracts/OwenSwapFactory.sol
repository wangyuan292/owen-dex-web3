// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOwenSwapFactory.sol";


contract OwenSwapFactory is IOwenSwapFactory{

    //手续费接收地址
    address public feeTo;
    //手续费设置管理员地址
    address public feeToSetter;

    //所有交易对数组
    address[] public allPairs;
    //交易对的映射存储
    mapping(address => mapping(address=>address)) public getPair;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    //构造函数 设置管理员地址
    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    //获取所有交易对(资金池长度)
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }


    function createPair(address tokenA, address tokenB) external returns(address pair){
        //校验两个token地址不能相等
        require(tokenA != tokenB, "OwenSwap: IDENTICAL_ADDRESSES");
        (address token0, address token1) =  tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA); //地址转化16进制后变成数字 比较大小. 按照统一规则对交易对的token进行处理.
        //token0不能为空地址
        require(token0 != address(0), "OwenSwap: ZERO_ADDRESS");
        //校验交易对是否存在 此种校验方式是否有问题? getPair[token1][token0]？
        require(getPair[token0][token1] == address(0), "OwenSwap: PAIR_EXISTS");

        //内联汇编
        bytes memory byteCode = type(SwapFactory).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        //提前计算pair 地址
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        //调用pair合约 初始化交易对
        IOwenSwapPair(pair).initialize(token0, token1);
        //放入交易对
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        //将pair对放入总交易池数组中
        allPairs.push(pair);
        //事件通知
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    //设置手续费接收地址
    function setFeeTo(address _feeTo) external {
        require(feeToSetter == msg.sender, "OwenSwap: FORBIDDEN");
        feeTo = _feeTo;
    }

}
