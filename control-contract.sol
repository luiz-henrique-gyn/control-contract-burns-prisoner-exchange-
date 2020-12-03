pragma solidity ^0.7.2;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

}

interface IERC20Token {
    
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    
}

contract Owned {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

}

contract Vault_Bit is Owned {
    
    using SafeMath for uint256;
    
    IERC20Token internal tokenA; 
    IERC20Token internal tokenB; 
    uint256 public balanceA;
    
    uint256 private constant _TIMELOCK = 90 days;
    
    mapping(address => mapping(address => uint256)) public contractBalance;
    mapping(address => mapping(address => uint256)) public contractExpiration;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    

    
    constructor(address theTokenA, address theTokenB) Owned(msg.sender) {
        tokenA = IERC20Token(theTokenA);
        tokenB = IERC20Token(theTokenB);
    }
    
    
    function burn_genesis(uint256 _amountToBurn) internal {
        
        require(msg.sender != address(0));
        tokenB.transfer(address(0), _amountToBurn);
        emit Transfer(address(this), address(0), _amountToBurn);
    }
    
    function depositA(uint256 _amount) internal returns (bool) { 
        
        require(tokenA.balanceOf(msg.sender) > 0);
        require(tokenA.transferFrom(msg.sender, address(this), _amount));
        balanceA = balanceA.add(_amount);
        emit Transfer(msg.sender, address(this), _amount);
        return true;
    }
    
    function depositB(uint256 _amount) internal returns (bool) {
        
        require(tokenB.balanceOf(msg.sender) > 0);
        require(tokenB.transferFrom(msg.sender, address(this), _amount));
        emit Transfer(msg.sender, address(this), _amount);
        uint256 _amountToBurn = _amount.mul(75).div(100);
        burn_genesis( _amountToBurn);
        uint256 _unBurnAmount = _amount.sub(_amountToBurn);
        contractBalance[msg.sender][address(tokenB)] = contractBalance[msg.sender][address(tokenB)] .add(_unBurnAmount);
        contractExpiration[msg.sender][address(tokenB)] = block.timestamp.add(_TIMELOCK);
        if(balanceA > _amount){
            require(tokenA.transfer(msg.sender, _amount));
            balanceA = balanceA.sub(_amount);
            emit Transfer(address(this), msg.sender, _amount);
        }else{
            require(tokenA.transfer(msg.sender, balanceA));
            balanceA = 0;
            emit Transfer(address(this), msg.sender,  _amount);
        }

        return true;
    }
    
    
    function deposit(address _tokenAddress, uint256 _amount) external returns (bool) {
        if(address(tokenA) == _tokenAddress){
            depositA(_amount);
         return true;
        }else if (address(tokenB) == _tokenAddress){
            depositB(_amount);
         return true;
        }

      return false; 
    }
    
    function withdraw() external {
        
        require(block.timestamp > contractExpiration[msg.sender][address(tokenB)], "Funds still in the contract.");
        uint256 amount = contractBalance[msg.sender][address(tokenB)];
        contractBalance[msg.sender][address(tokenB)] = 0;
        require(tokenB.transfer(msg.sender, amount));
        emit Transfer(address(this), msg.sender,  amount);
        
    }
    
}
