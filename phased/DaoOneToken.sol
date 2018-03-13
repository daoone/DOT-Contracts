pragma solidity ^0.4.18;

/**
 * @title NonZero
 */
contract NonZero {

// Functions with this modifier fail if he 
    modifier nonZeroAddress(address _to) {
        require(_to != 0x0);
        _;
    }

    modifier nonZeroAmount(uint _amount) {
        require(_amount > 0);
        _;
    }

    modifier nonZeroValue() {
        require(msg.value > 0);
        _;
    }
}

contract Owned {
    address public owner;

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function changeOwner(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

contract ERC20Token {
    uint256 public totalSupply;
    function balanceOf(address _owner) constant public returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) constant public returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

//  DaoOneToken
//  @title DaoOneToken - Main activities in DaoOne ecosystem.
//  @author Steak Guo - <cookedsteak708@gmail.com>
//  @caution All parameters of external functions should follow the sequence as <address, value>
contract DaoOneToken is Owned, ERC20Token, NonZero {
    using SafeMath for uint256;

    string  public name = "DaoOneToken";
    uint8   public decimals;
    string  public symbol = "DOT";
    string  public version = "DOT_0.1";
    uint256 public lockPeriod = 1 years;
    uint256 public startTime = now;
    bool    public transferEnable = false;
    
    address[] public ownerWallets;
    mapping (address => bool) public isOwnerWallet;

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) allowed;

    event AddWallets(address[] _wallets);
    event DisableWallet(address indexed wallet);

    modifier lockIsOver() {
        require(now >= startTime.add(lockPeriod));
        _;
    }

    modifier ownerWalletExists(address _walletAddress) {
        require(isOwnerWallet[_walletAddress]);
        _;
    }

    function DaoOneToken(uint256 initialSupply, uint8 decimalUnits) 
        public 
    {
        // owner is CoreWallet
        owner = msg.sender;
        balances[owner] = initialSupply;
        decimals = decimalUnits;
        isOwnerWallet[msg.sender] = true;
        ownerWallets.push(msg.sender);
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) 
        public 
        returns (bool success)
    {
        if (transferEnable || (isOwnerWallet[msg.sender])) {
            if (balances[msg.sender] >= _value && balances[_to] + _value >= balances[_to]) {
                balances[msg.sender] = balances[msg.sender].sub(_value);
                balances[_to] = balances[_to].add(_value);
                Transfer(msg.sender, _to, _value);
                return true;
            }
        }
        return false;
    }

    function transferFrom(address _from, address _to, uint256 _value) 
        public 
        returns (bool success) 
    {
        if (transferEnable || (isOwnerWallet[msg.sender])) {
            if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
                balances[_to] = balances[_to].add(_value);
                balances[_from] = balances[_from].sub(_value);
                allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
                Transfer(_from, _to, _value);
                return true; 
            } 
        }
        return false;
    } 

    function approve(address _spender, uint256 _value) 
        public
        returns (bool success) 
    {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) 
        constant 
        public returns (uint256 remaining) 
    {
        return allowed[_owner][_spender];
    }
   
    function addOwnerWallets(address[] _ownerWallets) 
        public 
        onlyOwner 
    {
        for (uint i = 0; i < _ownerWallets.length; i++) {
            require (!isOwnerWallet[_ownerWallets[i]] && _ownerWallets[i] != address(0));
            isOwnerWallet[_ownerWallets[i]] = true;
            ownerWallets.push(_ownerWallets[i]);
        }
        AddWallets(_ownerWallets);
    }

    function disableWallet(address _walletAddress) 
        onlyOwner
        public 
    {
        require(isOwnerWallet[_walletAddress] && _walletAddress != address(0));
        isOwnerWallet[_walletAddress] = false;
        for (uint i = 0; i < ownerWallets.length; i++) {
            if (ownerWallets[i] == _walletAddress) {
                delete ownerWallets[i];
                return;
            }
        }
        DisableWallet(_walletAddress);
    }

    function setLockPeriod(uint256 _time) 
        onlyOwner 
        public 
    {
        lockPeriod = _time;
    }

    function enableTransfer(bool _enable)
        onlyOwner
        public 
    {
        transferEnable = _enable;
    }
    
    function getOwnerWallets() external constant returns (address[]) {
        return ownerWallets;
    }
}


/**
 * Math operations with safety checks
 */
library SafeMath {
  function mul(uint a, uint b) internal pure returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint a, uint b) internal pure returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal pure returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }

  function max64(uint64 a, uint64 b) internal pure returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) internal pure returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}

