pragma solidity ^0.4.23;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/ownership/Ownable.sol";

/*
    Copyright 2018,

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


//////////////////////////////////////////////////////////////
//                                                          //
//  iTinyToken's ERC20                                      //
//                                                          //
//////////////////////////////////////////////////////////////

contract ERC20 is Ownable {

    using SafeMath for uint256;

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    uint256 public constant blockEndICO = 5406151; // 167d * 3600s / 14.2s + 5363813 (09/16/2018) @ 2:00am (UTC)
    /* Public variables for the ERC20 token */
    string public constant standard = "ERC20 iTiny";
    uint8 public constant decimals = 8; // hardcoded to be a constant
    uint256 public totalSupply;
    uint256 public distributed;
    string public name;
    string public symbol;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        return transferFrom(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(block.timestamp > blockEndICO || msg.sender == owner);
        require(_to != address(0));

        // SafeMath.sub will throw if there is not enough balance.
        balances[_from] = balances[_from].sub(_value);
        if (_from != msg.sender)
            allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        balances[_to] = balances[_to].add(_value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function increaseApproval(address _spender, uint _addedValue) external returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) external returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /* Approve and then communicate the approved contract in a single tx */
    function approveAndCall(address _spender,uint256 _value, bytes _extraData) external returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);

        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }
}

interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external;
}

contract ITinyToken is ERC20 {

    // Contract variables and constants
    uint256 constant maxSupply = 50000000000000000; // 500M * 10^decimals
    address public itinyAddr = 0x0; // CHANGE FOR REAL BENEFICIARY!!
    uint256 public tokenReward;

    mapping (address => uint256) public balancesLocked;

    //Declare logging events
    event LogDeposit(address sender, uint amount);
    event LogWithdrawal(address receiver, uint amount);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor () public {
        balances[this] = (maxSupply * 80) / 100; // 80%
        distributed = maxSupply - balances[this];
        balances[itinyAddr] = distributed; // 20%
        totalSupply = maxSupply;      // Max supply
        name = "iTinyToken";
        symbol = "ITNY";
    }

    function () public payable {
        buy();   // Allow to buy tokens sending ether directly to contract
    }

    function tokensDelivered() internal view returns (uint256 tokens) {
        uint256 buyTime = block.timestamp; // only one read from state
        //ufixed128x19 tokensPerEth = 3182.7 wei; // 318.27€/ETH * 10
        uint256 tokenBase = (msg.value * 31827 * decimals) / 1e18;
        uint256 distributed = totalSupply.sub(balances[this]);

        /* UNTIL...
        End Angels' Week 70%
        1523836800 == 04/16/2018 @ 12:00am (UTC)
        Pre-sale 30%
        1526428800 == 05/16/2018 @ 12:00am (UTC)
        Pre-sale 20%
        1529107200 == 06/16/2018 @ 12:00am (UTC)
        ICO 15%
        1531699200 == 07/16/2018 @ 12:00am (UTC)
        ICO 10%
        1534377600 == 08/16/2018 @ 12:00am (UTC)
        ICO 5%
        1537056000 == 09/16/2018 @ 12:00am (UTC)
        */

        // Test 90k€ cap for Angels' Week
        if (buyTime < 1523836800){
            if (distributed + tokenBase < 900000 * decimals){ // <900k tokens
                return (tokenBase * 170) / 100;
            } else {
                return (tokenBase * 130) / 100;
            }
        }

        /* GREAT DISCOUNT FOR GREAT INVESTORS */
        else if (tokenBase > 500000 * decimals) {
            // During Pre-sale
            if (buyTime < 1529107200) {
                return (tokenBase * 150) / 100;
            }
            // During ICO
            if (buyTime < 1537056000) {
                return (tokenBase * 135) / 100;
            }
        }

        // Test 5M€ cap for pre-sale until 06/16/2018 @ 12:00am (UTC)
        if (distributed < 50e6 * decimals) { // <50M tokens
            if (buyTime < 1526428800){   // 05/16/2018 @ 12:00am (UTC)
                return (tokenBase * 130) / 100;
            }

            if (buyTime < 1529107200) {
                return (tokenBase * 120) / 100;
            }
        }

        // Test 50M€ cap for ICO until 09/16/2018 @ 12:00am (UTC)
        if (distributed < 500e6 * decimals){ // <500M tokens
            if (buyTime < 1531699200) {   // 07/16/2018 @ 12:00am (UTC)
                return (tokenBase * 115) / 100;
            }

            if (buyTime < 1534377600){   // 08/16/2018 @ 12:00am (UTC)
                return (tokenBase * 110) / 100;
            }

            if (buyTime < 1537056000) {
                return (tokenBase * 105) / 100;    // till end 09/16/2018 @ 12:00am (UTC)
            }
        }
    }

    function deposit() external payable onlyOwner returns(bool success) {
        assert (address(this).balance + msg.value >= address(this).balance); // Check for overflows
        tokenReward = address(this).balance / distributed;

        //executes event to reflect the changes
        emit LogDeposit(msg.sender, msg.value);
        return true;
    }
/*
    function withdraw(uint256 value) external onlyOwner {
        //send eth to owner address
        msg.sender.transfer(value);

        //executes event to register the changes
        emit LogWithdrawal(msg.sender, value);
    }
*/
    function buy() public payable {
        require(distributed < maxSupply);
        require(block.timestamp < blockEndICO);

        uint256 tokenAmount = tokensDelivered();
        transferBuy(msg.sender, tokenAmount);

        itinyAddr.transfer(msg.value);
    }

    function transferBuy(address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));

        // SafeMath.sub will throw if there is not enough balance.

        distributed = distributed.add(_value);
        balances[_to] = balances[_to].add(_value);
        balances[this] = balances[this].sub(_value);

        emit Transfer(this, _to, _value);
        return true;
    }

    function burn(address _addr) external onlyOwner{
        totalSupply = totalSupply.sub(balances[_addr]);
        balances[_addr] = 0;
    }

    function freeze(address _addr) external {
        require(block.timestamp <= blockEndICO || msg.sender == owner);
        uint256 _amount;
        if (owner == msg.sender) {
            _amount = balances[_addr];
            balances[_addr] = 0;
            balancesLocked[_addr] = balancesLocked[_addr].add(_amount);
            balances[0] = balances[0].add(_amount);
        } else {
            _amount = balances[msg.sender];
            balances[msg.sender] = 0;
            balancesLocked[msg.sender] = balancesLocked[msg.sender].add(_amount);
            balances[0] = balances[0].add(_amount);
        }
    }
}
