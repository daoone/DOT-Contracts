pragma solidity ^0.4.18;

/*
 *  The improved version of Multisignature
 *
 */
contract MultiSig {
    uint public maxMemberCount; 
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
            if (txn.exeContract.call(bytes32(keccak256(txn.funcName)), txn.destination, txn.value)) {
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