pragma solidity ^0.4.18;

import "./DaoOneToken.sol";

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
        require(msg.sender == admin || msg.sender == owner);
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