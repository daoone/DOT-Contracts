pragma solidity ^0.4.18;

import "./DaoOneToken.sol";
import "./MultiSig.sol";
import "./RewardWallet.sol";
import "./CrowdfundWallet.sol";

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
        uint256 crowdfunding,
        DaoOneToken _dot,
        RewardWallet _rw,
        CrowdfundWallet _crowd
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

        dot = _dot;
        rw = _rw;
        crowd = _crowd;
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
        for (uint i=0; i<members.length - 1; i++)
            if (members[i] == _member) {
                members[i] = members[members.length - 1];
                break;
            }
        members.length -= 1;    
        
        if (_newRequired > 0) {
            required = uint(_newRequired);
        }
    }
}