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

/*
 *  The improved version of Multisignature
 *
 */
contract MultiSig {
    uint public maxMemberCount = 10; 
    uint public required; 
    uint public transactionCount;
    
    address[] public members; 
    address internal exeContract; 

    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping (address => bool)) public confirmations;
    mapping (address => bool) public isMember; 

    struct Transaction {
        address exeContract;
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

    function submitTransaction(address _from, address _destination, uint _value, bytes _data, address _contract, string _funcName)
        internal
        returns (uint transactionId)
    {
        transactionId = addTransaction(_destination, _value, _data, _contract, _funcName);
        confirmTransaction(_from, transactionId);
    }

    function addTransaction(address _destination, uint _value, bytes _data, address _contract, string _funcName)
        internal
        notNull(_destination)
        returns (uint transactionId)
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            exeContract: _contract,
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
        notExecuted(_transactionId)
    {
        if (isConfirmed(_transactionId)) {
            Transaction storage txn = transactions[_transactionId];
            txn.executed = true;
            if (txn.exeContract.call(bytes4(bytes32(keccak256(txn.funcName))), txn.destination, txn.value)) {
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
    /// _count Additional owner counts
    function addMaxMemberCount(uint _count) 
        memberExists(msg.sender)
        internal
    {
        maxMemberCount += _count;
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
        Owned()
        public 
    {
        // owner is CoreWallet
        totalSupply = initialSupply;
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
   
    function addTotalSupply(uint256 _value) 
        onlyOwner
        public 
    {
        require(_value > 0);
        balances[msg.sender] = balances[msg.sender].add(_value);
        totalSupply = totalSupply.add(_value);
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

contract CoreWallet is MultiSig, NonZero {
    DaoOneToken     public dot;
    RewardWallet    public rw;
    CrowdfundWallet public crowd;
    address public initialOwner;

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
        initialOwner = msg.sender;

        dot = new DaoOneToken(initSupply, decimals);
        rw = new RewardWallet(_rewardAdmin, dot);
        crowd = new CrowdfundWallet(crowdfunding, dot);
        address[] memory ad = new address[](2);
        ad[0] = rw;
        ad[1] = crowd;
        dot.addOwnerWallets(ad);
        dot.transfer(address(crowd), crowdfunding);
    }

    function changeDotAddress(address dotDeployed) public {
        require(msg.sender == initialOwner);
        dot = DaoOneToken(dotDeployed);

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

    function removeMember(address _member, uint256 _newRequired)
        internal
        memberExists(_member)
    {
        isMember[_member] = false;
        for (uint i = 0; i < members.length - 1; i++) {
            if (members[i] == _member) {
                members[i] = members[members.length - 1];
                break;
            }
        }
        members.length -= 1;    
        
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
    event ChangeAdmin(address indexed oldAdmin, address indexed newAdmin, uint256 NoUseValue);

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

    function changeAdmin(address _admin, uint256 _value) 
        external
        onlyOwner
    {
        if (_admin != address(0x0)) {
            ChangeAdmin(admin, _admin, _value);
            admin = _admin;
        }
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

