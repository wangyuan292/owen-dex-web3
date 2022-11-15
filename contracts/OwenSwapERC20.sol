// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract OwenSwapERC20 {

    using SafeMath for uint;

    //LP Token名称
    string public constant name = 'OwenSwap LP Token';
    //LP Token符号
    string public constant symbol = 'OSLP';
    //精度
    uint8 public constant decimals = 18;
    //总供应量
    uint  public totalSupply;

    //映射 每个地址的余额
    mapping(address => uint) public balanceOf;

    //用来记录每个地址的授权分布，用于非直接转移代币
    mapping(address => mapping(address => uint)) public allowance;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    //记录合约中每个地址使用链下签名消息交易的数量，用来防止重放攻击。
    mapping(address => uint256) public nonces;
    //事件 批准
    event Approval(address indexed owner, address indexed spender, uint value);
    //事件 交易
    event Transfer(address indexed from, address indexed to, uint value);

    //构造器 计算DOMAIN_SEPARATOR的值
    //根据EIP-712的介绍，该值通过domainSeparator = hashStruct(eip712Domain)计算。这其中eip712Domain是一个名为EIP712Domain的结构，它可以有以下一个或者多个字段
    //TODO 这个值的作用
    constructor() public {

        //当前链的ID，注意因为Solidity不支持直接获取该值，所以使用了内嵌汇编来获取
        uint chainId;
        assembly {
            chainId := chainid()
        }

        //EIP712Domain
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),  //可读的签名域的名称，例如Dapp的名称，在本例中为代币名称
                keccak256(bytes('1')), //version
                chainId,
                address(this)  //验证合约的地址，在本例中就是本合约地址了
            )
        );
    }

    //LP 代币增发
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(this), to, value);
    }

    //LP 代币销毁
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    //LP 代币授权(内部方法)
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    //LP 代币转移(内部方法)
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    //主要由外部第三方合约进行调用
    function transfer(address from , address to, uint value) external returns(bool) {
        //如果没有进行授权
        if (allowance[from][msg.sender] != uint256(-1)) {
            //库函数.sub(value)调用时无法通过SafeMath的require检查 导致交易回滚
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to , value);
        return true;
    }

    //线下签名消息进行授权操作
    //TODO 原理
    function permit (address owner, address spender, uint value, uint deadline, uint8 v, byte32 r, byte32 s) external {
        require(deadline >= block.timestamp, "OwenSwap: EXPIRE");
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'OwenSwap: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }

}
