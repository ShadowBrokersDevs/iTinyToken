pragma solidity ^0.4.19;

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


library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0)
            return 0;
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function Ownable() internal {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require((uint256(newOwner) % 10000 > 0) && (newOwner != address(0)));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}


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
    uint256 constant initialSupply = 0;
    uint256 constant maxSupply = 1000000000000000;
    string constant tokenName = "iTinyToken";
    string constant tokenSymbol = "ITNY";

    address public itinyAddr = 0x0; // CHANGE FOR REAL BENEFICIARY!!
    uint256 public tokenReward;

    //Declare logging events
    event LogDeposit(address sender, uint amount);
    event LogWithdrawal(address receiver, uint amount);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function ITinyToken() public {
        balances[itinyAddr] = maxSupply * 0.15;
        totalSupply = balances[itinyAddr];  // Update total supply
        name = tokenName;             // Set the name for display purposes
        symbol = tokenSymbol;         // Set the symbol for display purposes
    }

    function () public payable {
        buy();   // Allow to buy tokens sending ether directly to contract
    }

    function tokensDelivered() internal returns (uint256 price) {
        uint256 buyTime = block.timestamp; // only one read from state
        //ufixed128x19 tokensPerEth = 3182.7 wei; // 318.27€/ETH * 10
        uint256 tokenBase = msg.value * 31827/10;

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

        /* GREAT DISCOUNT FOR GREAT INVESTORS */
        if (tokenBase > 500000) {
            // During Pre-sale
            if (buyTime < 1529107200 && buyTime > 1523836800) {
                return tokenBase * 1.5;
            }
            // During ICO
            if (buyTime < 1537056000 && buyTime > 1523836800) {
                return tokenBase * 1.35;
            }
        }

        // Test 90k€ cap for Angels' Week
        if (buyTime < 1523836800){
            if (totalSupply + tokenBase < 90000000000000){ // <900k tokens
                return tokenBase * 1.7;
            } else {
                return tokenBase * 1.3;
            }
        }

        // Test 5M€ cap for pre-sale until 06/16/2018 @ 12:00am (UTC)
        if ((totalSupply < 5 finney) && (buyTime < 1529107200)) { // <50M tokens
            if (buyTime < 1526428800){   // 05/16/2018 @ 12:00am (UTC)
                return tokenBase * 1.3;
            } else {
                return tokenBase * 1.2;
            }
        }

        // Test 50M€ cap for ICO until 09/16/2018 @ 12:00am (UTC)
        if ((totalSupply < 50 finney) && (buyTime < 1537056000)){ // <500M tokens
            if (buyTime < 1531699200) {   // 07/16/2018 @ 12:00am (UTC)
                return tokenBase * 1.15;
            }

            if (buyTime < 1534377600){   // 08/16/2018 @ 12:00am (UTC)
                return tokenBase * 1.1;
            }

            return tokenBase * 1.05;    // till end 09/16/2018 @ 12:00am (UTC)
    }

    function deposit() external payable onlyOwner returns(bool success) {
        assert (address(this).balance + msg.value >= address(this).balance); // Check for overflows
        tokenReward = address(this).balance / totalSupply;

        //executes event to reflect the changes
        emit LogDeposit(msg.sender, msg.value);
        return true;
    }

    function withdraw(uint256 value) external onlyOwner {
        //send eth to owner address
        msg.sender.transfer(value);

        //executes event to register the changes
        emit LogWithdrawal(msg.sender, value);
    }

    function buy() public payable {
        require(totalSupply <= maxSupply);
        require(block.timestamp < blockEndICO);

        uint256 tokenAmount = tokensDelivered();
        transferBuy(msg.sender, tokenAmount);

        itinyAddr.transfer(msg.value);
    }

    function transferBuy(address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));

        // SafeMath.add will throw if there is not enough balance.
        totalSupply = totalSupply.add(_value);

        //balances[itinyAddr] = balances[itinyAddr].add(_value);
        balances[_to] = balances[_to].add(_value);

        emit Transfer(this, _to, _value);
        emit Transfer(this, itinyAddr, _value);
        return true;
    }

    function burn(address addr) external onlyOwner{
        totalSupply = totalSupply.sub(balances[addr]);
        balances[addr] = 0;
    }

    function freeze(address _addr) external {
        require(block.timestamp <= blockEndICO || msg.sender == owner);
        uint256 _amount;
        if (owner == msg.sender) {
            _amount = balances[_addr];
            balances[_addr] = 0;
            balancesLocked[_addr] += _amount;
            balances[0] += _amount;
        } else {
            _amount = balances[msg.sender];
            balances[msg.sender] = 0;
            balancesLocked[msg.sender] += _amount;
            balances[0] += _amount;
        }
    }
}
