pragma solidity ^0.4.18;

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
    // function approve(address _spender, uint256 _value) public returns (bool success);
    // function allowance(address _owner, address _spender) constant public returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    // event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract MultiSig {
    // 总拥有者
    uint public maxMemberCount; 
    // 要求表决人数
    uint public required; 
    uint public transactionCount;
    // 拥有者地址
    address[] public members; 
    // 将要执行的token协议
    address internal exeContract; 

    // 所有交易
    mapping (uint => Transaction) public transactions;
    // 所有交易表决
    mapping (uint => mapping (address => bool)) public confirmations;
    // 拥有者列表和对应状态
    mapping (address => bool) public isMember; 

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        string funcName;
    }

    event Confirmation(address indexed sender, uint indexed transactionId);
    event Revocation(address indexed sender, uint indexed transactionId);
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    /*
     *  Modifiers
     */
    modifier onlyMultiSig() {
        require(msg.sender == address(this));
        _;
    }
 
    modifier memberDoesNotExist(address member) {
        require(!isMember[member]);
        _;
    }
 
    modifier memberExists(address member) {
        require(isMember[member]);
        _;
    }
 
    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].destination != 0);
        _;
    }
 
    modifier confirmed(uint transactionId, address member) {
        require(confirmations[transactionId][member]);
        _;
    }
 
    modifier notConfirmed(uint transactionId, address member) {
        require(!confirmations[transactionId][member]);
        _;
    }
 
    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed);
        _;
    }
 
    modifier notNull(address _address) {
        require(_address != 0);
        _;
    }
 
    modifier validRequirement(uint memberCount, uint _required) {
        require(memberCount <= maxMemberCount && _required <= memberCount && _required != 0 && memberCount != 0);
        _;
    }

    /**
        Constructor
     */
    function MultiSig(address _members, uint _required) 
        public 
        validRequirement(_members.length, _required)
    {
        for (uint i = 0; i < _members.length; i++) {
            require (!isMember[_members[i]] && _members[i] != address(0));
            isMember[_members[i]] = true;
        }
        members = _members;
        required = _required;
    }

    function submitTransaction(address _from, address _destination, uint _value, bytes _data, string _funcName)
        internal
        returns (uint transactionId)
    {
        transactionId = addTransaction(_destination, _value, _data, _funcName);
        confirmTransaction(_from, transactionId);
    }

    function addTransaction(address _destination, uint _value, bytes _data, string _funcName)
        internal
        notNull(_destination)
        returns (uint transactionId)
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false,
            funcName: _funcName
        });
        transactionCount += 1;
        Submission(transactionId);
    }

    function confirmTransaction(address _from, uint _transactionId)
        internal
        memberExists(_from)
        transactionExists(_transactionId)
        notConfirmed(_transactionId, _from)
    {
        confirmations[_transactionId][_from] = true;
        Confirmation(_from, _transactionId);
        executeTransaction(_transactionId);
    }
 
    function executeTransaction(uint _transactionId) 
        internal
        notExecuted(_transationId)
    {
        if (isConfirmed(_transactionId) && exeContract != address(0)) {
            Transaction storage txn = transactions[_transactionId];
            txn.executed = true;
            if (exeContract.call(bytes32(keccak256(txn.funcName)), txn.destination, txn.value)) {
                Execution(_transactionId);
            } else {
                ExecutionFailure(_transactionId);
                txn.executed = false;
            }
        }    
    }

    function revokeConfirmation(address _from, uint _transactionId)
        internal
        memberExists(_from)
        confirmed(_transactionId, _from)
        notExecuted(_transactionId)
    {
        confirmations[_transactionId][_from] = false;
        Revocation(_from, _transactionId);
    }

    function isConfirmed(uint _transactionId)
        public
        constant
        returns (bool)
    {
        uint count = 0;
        for (uint i = 0; i < members.length; i++) {
            if (confirmations[_transactionId][members[i]]) {
                count += 1;
            }
            if (count == required) {
                return true;
            }
        }
    }


    function getTransactionIds(uint _from, uint _to, bool _pending, bool _executed)
        public
        constant
        returns (uint[] transactionIds)
    {
        uint[] memory transactionIdsTemp = new uint[](transactionCount);
        uint count = 0;
        uint i;
        for (i = 0; i < transactionCount; i++) {
            if (_pending && !transactions[i].executed || _executed && transactions[i].executed) {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        }
        transactionIds = new uint[](_to - _from);
        for (i = _from; i < _to; i++) {
            transactionIds[i - _from] = transactionIdsTemp[i];
        }
    }

    /**
        Get details of a confirmation
     */
    function getConfirmations(uint _transactionId)
        public
        constant
        returns (address[] _confirmations)
    {
        address[] memory confirmationsTemp = new address[](members.length);
        uint count = 0;
        uint i;
        for (i = 0; i < members.length; i++) {
            if (confirmations[_transactionId][members[i]]) {
                confirmationsTemp[count] = members[i];
                count += 1;
            }
        }    
        _confirmations = new address[](count);
        for (i = 0; i < count; i++) {
            _confirmations[i] = confirmationsTemp[i];
        }
    }

    function getConfirmationCount(uint _transactionId)
        public
        constant
        returns (uint count)
    {
        for (uint i = 0; i < members.length; i++) {
            if (confirmations[_transactionId][members[i]]) {
                count += 1;
            }
        }
    }

    function getTransactionCount(bool _pending, bool _executed)
        public
        constant
        returns (uint count)
    {
        for (uint i = 0; i < transactionCount; i++) {
            if (_pending && !transactions[i].executed || _executed && transactions[i].executed) {
                count += 1;
            }
        }
    }

    function getMembers()
        public
        constant
        returns (address[])
    {
        return members;
    }

    /**
        Increase max owner counts
     */
    /// @_count Additional owner counts
    function addMaxMemberCount(uint _count) 
        memberExists(msg.sender)
        internal
    {
        maxMemberCount += _count;
    }
}

/**
    DaoOneToken
/// @title DaoOneToken - Main activities in DaoOne ecosystem.
/// @author Steak Guo - <cookedsteak708@gmail.com>
/// @caution All parameters of external functions should follow the sequence as <address, value>
 */
contract DaoOneToken is Owned, ERC20Token {
    using SafeMath for uint256;

    string  public name = "DaoOneToken";
    uint8   public decimals;
    string  public symbol = "DOT";
    string  public version = "DOT_0.1";
    uint256 public lockPeriod = 1 years;
    uint256 public startTime = now;
    bool    public transferEnable = false;

    uint256 public exchangeRate = 100;
    uint256 public exchangeEtherLimit = 10 ether;

    mapping (address => uint256) public balances;

    event Support(address indexed supporter, uint256 supportValue, uint256 dotValue);

    modifier lockIsOver() {
        require(now >= startTime.add(lockPeriod));
        _;
    }

    function DaoOneToken(uint256 initialSupply, uint8 decimalUnits) 
        public 
    {
        // owner is CoreWallet
        owner = msg.sender;
        balances[owner] = initialSupply;
        decimals = decimalUnist;
    }

    function transfer(address _to, uint256 _value) 
        public 
        returns (bool success) 
    {
        if ( (msg.sender != owner && transferEnable) ||
            (msg.sender == owner)
        ) {
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

    function withdraw(address _to, uint256 _value)
        onlyOwner
        public
    {
        if (_value > this.balance) {
            _to.transfer(_value);
        }
    }

    function support() 
        payable 
        public 
    {
        uint256 distrbution;
        uint256 _refund = 0;
        if ((msg.value > 0) && (tokenExchange(msg.value) < xmb.balances(this))) {
            if (msg.value > exchangeEtherLimit) {
                // 超过兑换限制会把多余的退回去
                _refund = msg.value.sub(exchangeEtherLimit);
                msg.sender.transfer(_refund);
                distrbution = tokenExchange(exchangeEtherLimit);
            } else {
                distrbution = tokenExchange(msg.value);
            }
            xmb.transfer(msg.sender, distrbution);
        }
        RechargeFaith(msg.sender, msg.value, distrbution, _refund);
    }

    function tokenExchange(uint256 _amount)
        internal
        returns (uint256)
    {
        return _amount.mul(exchangeRate);    
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
    Contract Topology:
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

contract CoreWallet is MultiSig {
    DaoOneToken  public dot;
    RewardWallet public rw;
    Crowdfunding public crowd;

    function CoreWallet(
        uint256 initSupply,
        uint8 decimals,
        uint256 crowdfunding
        )
        public
    {
        dot = new DaoOneToken(initSupply, decimals);
        rw = new RewardWallet();
        crowd = new Crowdfunding();
        exeContract = address(dot);
        dot.transfer(address(crowd), crowdfunding);
    }

    // 多签名token转移提议  _funcName: transfer(address, uint256)
    function transferSubmission(address _destination, uint256 _value, bytes _data, string _funcName)
        external
        returns (uint transactionId)
    {
        return submitTransaction(msg.sender, _destination, _value, _data, _funcName);
    }
    // 确认提议
    function transferConfirmation(uint _transactionId)
        external
    {
        confirmTransaction(msg.sender, _transactionId);
    }
    // 否决提议
    function transferVeto(uint _transactionId)
        external
    {
        revokeConfirmation(msg.sender, _transactionId);
    }
    // 执行决议
    function transferExecution(uint _transactionId)
        external
        notExecuted(_transactionId)
    {
        require(isConfirmed(_transactionId));
    }

    // Add new members or Add required counts
    function addMember(address _newMember, uint256 _newRequired) public {
        if (_newMember != 0) {
            members.push(_newMember);
        }
        if (_newRequired > 0) {
            required = uint(_newRequired);
        }
    }

}

/**
    RewardWallet
 */
contract RewardWallet is Owned {
    
    function RewardWallet() public {
        owner = msg.sender;
    }
}

contract Crowdfunding {

    function support() 
        payable 
        public
    {

    }
}

library SafeMath {
    function mul(uint a, uint b) internal pure returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint a, uint b) internal pure returns (uint) {
        uint c = a / b;
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
}