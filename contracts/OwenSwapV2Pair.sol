;// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libraries/UQ112x112.sol";
import "./libraries/SafeMath.sol";


contract OwenSwapV2Pair {
    using SafeMath for uint;
    using UQ112x112 for uint224;
    //最小流动性
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    //SELECTOR用来计算ERC-20合约中转移资产的transfer对应的函数选择器 TODO ？
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    //工厂合约地址
    address public factory;
    address public token0;
    address public token1;

    //恒定乘积中两种资产的数量
    uint112 private reserve0;
    uint112 private reserve1;
    //一个存储槽256位 两个reserve占用了224 剩下时间戳使用32位
    //交易时 区块创建时间
    uint32  private blockTimestampLast;

    //交易对 两种代币的价格
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // 恒定值K

    uint public totalFee;
    uint public alpha;
    uint public beta;


    uint private unlocked = 1;

    event Sync(uint112 reserve0, uint112 reserve1);

    //构造函数 初始化工厂合约地址
    constructor() public {
        factory = msg.sender;
    }

    //防止重入攻击
    modifier lock() {
        require(unlocked == 1, "OwenSwap: LOCKED");
        unlocked = 0;
        _; //执行函数代码
        unlocked = 1;
    }

    //获取当前交易对中的资产信息以及最近一次的交易区块时间
    function getReserves() public view returns(uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    //发送代币，使用代币的call函数去调用代币合约transfer来发送代币，在这里会检查call调用是否成功以及返回值是否为true
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        //校验交易是否成功  //TODO  abi调用
        require(success && (data.lenght == 0 || abi.decode(data, (bool))), 'OwenSwap: TRANSFER_FAILED');
    }

    //供factory合约中创建交易对时进行合约的初始化
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "OwenSwap: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'OwenSwap: OVERFLOW');
        //当前区块时间  因为区块时间是uint 避免益处 进行取模操作
        //大约在2106/02/07会超过32位大小
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        //计算当前区块与上一次区块的时间
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        //同一区块内的交易 不会计算价格累计 否则进行价格累计计算 //TODO 不知道价格累计的作用和算法
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        //更新恒定乘积中的reserve的值，同时更新block时间为当前block时间
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        //触发同步事件
        emit Sync(reserve0, reserve1);
    }

    //计算开发团队手续费抽佣
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        //手续费接收地址
        address feeTo = IOwenSwapFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }


    }

}
