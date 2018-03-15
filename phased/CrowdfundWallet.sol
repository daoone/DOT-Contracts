pragma solidity ^0.4.18;

import "./NonZero.sol";
import "./SafeMath.sol";
import "./DaoOneToken.sol";

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
    // Withdraw into multisig wallet
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