pragma solidity ^0.4.18;

import "./helpers/SafeMath.sol";
import "./helpers/MultiSig.sol";
import "./helpers/NonZero.sol";

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
        onlyOwner 
        public 
        returns (bool success) 
    {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] = balances[_to].add(_value);
            balances[_from] = balances[_from].sub(_value);
            allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
            Transfer(_from, _to, _value);
            return true; 
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
        }
        AddWallets(_ownerWallets);
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
    
}

/**
    CoreWallet------------------------------+
    |   MultiSig----------------------------|  \\
    |   |   DaoOneToken---------------------|===\\
    |   |   |   [CoreWallet] => $dot$       |=====》 API
    |   |   |   [RewardWallet] => $dot$     |===//
    |   |   +-------------------------------+  //
    |   |   RewardWallet--------------------|
    |   |   |                               |
    |   |   +-------------------------------+
    |   |   Crowdfunding--------------------|
    |   |   |                               |
    |   |   +-------------------------------+
    |   +-----------------------------------+
    +---------------------------------------+
 */

contract CoreWallet is MultiSig, NonZero {
    DaoOneToken     public dot;
    RewardWallet    public rw;
    CrowdfundWallet public crowd;

    function CoreWallet(
        address[] _members, 
        address _rewardAdmin,
        uint _required,
        uint256 initSupply,
        uint8 decimals,
        uint256 crowdfunding
        )
        public
        validRequirement(_members.length, _required)
    {
        for (uint i = 0; i < _members.length; i++) {
            require (!isMember[_members[i]] && _members[i] != address(0));
            isMember[_members[i]] = true;
        }
        members = _members;
        required = _required;
        
        dot = new DaoOneToken(initSupply, decimals);
        rw = new RewardWallet(_rewardAdmin, dot);
        crowd = new CrowdfundWallet(crowdfunding, dot);
        address[] memory ad = new address[](2);
        ad[0] = rw;
        ad[1] = crowd;
        dot.addOwnerWallets(ad);
        dot.transfer(address(crowd), crowdfunding);
    }

    //  eg: @_funcName transfer(address, uint256)
    function transferSubmission(address _destination, uint256 _value, bytes _data, address _exeContract, string _funcName)
        external
        memberExists(msg.sender)
        nonZeroAddress(_exeContract)
        returns (uint transactionId)
    {
        return submitTransaction(msg.sender, _destination, _value, _data, _exeContract, _funcName);
    }
    
    function transferConfirmation(uint _transactionId)
        memberExists(msg.sender)
        external
    {
        confirmTransaction(msg.sender, _transactionId);
    }
    
    function transferVeto(uint _transactionId)
        memberExists(msg.sender)
        external
    {
        revokeConfirmation(msg.sender, _transactionId);
    }

    // additional Transaction Execution
    function transferExecution(uint _transactionId)
        external
        memberExists(msg.sender)
        notExecuted(_transactionId)
    {
        executeTransaction(_transactionId);
    }

    // Add new members or Add required counts
    function addMember(address _newMember, uint256 _newRequired) 
        internal
    {
        if (_newMember != 0) {
            members.push(_newMember);
        }
        if (_newRequired > 0) {
            required = uint(_newRequired);
        }
    }
}

// Reward Wallet
contract RewardWallet is Owned {
    using SafeMath for uint256;

    address public admin;
    DaoOneToken public dot;

    event GiveRewards(address indexed user, uint256 value, address indexed admin);

    function RewardWallet(address _admin, DaoOneToken _dot) public {
        owner = msg.sender;
        admin = _admin;
        dot = _dot;
    }

    function giveRewards(address _to, uint256 _value) public {
        require(msg.sender == admin);
        require(_value < dot.balanceOf(this));
        dot.transfer(_to, _value);
        GiveRewards(_to, _value, msg.sender);
    }
}

// Crowdfund Wallet
contract CrowdfundWallet is Owned, NonZero {
    using SafeMath for uint256;

    DaoOneToken public dot;
    uint8 public exchangeRate = 100;
    uint256 public exchangeEtherLimit = 10 ether;
    uint256 public remainingSupply;

    event Support(address indexed supporter, uint256 supportValue, uint256 dotValue, uint256 refundEther);
    event ChangeRate(uint8 _oldRate, uint8 _newRate, address _noUse);

    function CrowdfundWallet(uint256 _remainingSupply, DaoOneToken _dot) public {
        owner = msg.sender;
        remainingSupply = _remainingSupply;
        dot = _dot;
    }

    function support() payable public {
        uint256 distrbution;
        uint256 _refund = 0;
        if ((msg.value > 0) && (tokenExchange(msg.value) < dot.balanceOf(this))) {
            if (msg.value > exchangeEtherLimit) {
                // Do Refund
                _refund = msg.value.sub(exchangeEtherLimit);
                msg.sender.transfer(_refund);
                distrbution = tokenExchange(exchangeEtherLimit);
            } else {
                distrbution = tokenExchange(msg.value);
            }
            dot.transfer(msg.sender, distrbution);
        }
        Support(msg.sender, msg.value, distrbution, _refund);
    }

    function tokenExchange(uint256 _amount)
        internal
        view
        returns (uint256)
    {
        return _amount.mul(exchangeRate);    
    }

    // Through CoreWallet Call
    function changeRate(address _noUse, uint8 _newRate) 
        external
        onlyOwner
        nonZeroAmount(_newRate)
    {
        uint8 oldRate = exchangeRate;
        exchangeRate = _newRate;
        ChangeRate(oldRate, exchangeRate, _noUse);
    }

    // Through CoreWallet Call
    function withdraw(address _to, uint256 _value)
        external
        onlyOwner
        nonZeroAmount(_value)
        nonZeroAddress(_to)
    {
        if (_value > this.balance) {
            _to.transfer(_value);
        }
    }
}