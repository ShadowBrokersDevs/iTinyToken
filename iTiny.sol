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
    mapping (address => uint256) public holdUntil;
    mapping (address => mapping (address => uint256)) internal allowed;
    /* https://www.etherchain.org/charts/blocksPerDay */
    //uint256 public constant blockEndICO = 6755118; // 163d(07/21) * 5700 blocks/d + 582601
    uint256 public constant timeEndSale = 1543622400; // It's a timestamp
    /* Public variables for the ERC20 token */
    string public constant standard = "ERC20 iTiny";
    uint8 public constant decimals = 8; // hardcoded to be a constant
    uint32 internal constant units = 1e8;
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
        uint256 timestamp = block.timestamp;
        require(_to != address(0));
        if (msg.sender != owner) {
            require(holdUntil[_from] == 0 || timestamp > holdUntil[_from]);
            require(timestamp > timeEndSale);
            if (_from != msg.sender)
                allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        }
        // SafeMath.sub will throw if there is not enough balance.
        balances[_from] = balances[_from].sub(_value);
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
    address public itinyAddr = ; // CHANGE FOR REAL BENEFICIARY!!
    uint256 public tokenReward;

    mapping (address => uint256) public balancesLocked;
    mapping (address => uint8) public isKyc;

    //Declare logging events
    event LogDeposit(address sender, uint amount);
    event LogWithdrawal(address receiver, uint amount);
    event ReserveFunds(address sender, uint amount);
    event knownCustomer(address customer);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor () public {
        balances[this] = (maxSupply * 80) / 100; // 80%
        distributed = maxSupply.sub(balances[this]);
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
        //ufixed128x19 tokensPerEth = 4641.9 ; // 464.19€/ETH * 10
        uint256 tokenBase = (msg.value * 46419 * units) / 1e19; // /(1e18*10)
        uint256 distributed = totalSupply.sub(balances[this]);

        /* UNTIL...
        End Angels' Month 50% 25M iti
        1535760000 == 09/01/2018 @ 12:00am (UTC)
        Pre-Sale 12% 100M iti
        1538352000 == 10/01/2018 @ 12:00am (UTC)
        Token Sale          500M iti
        Sale 9%
        1541030400 == 11/01/2018 @ 12:00am (UTC)
        Sale 6%
        1543622400 == 12/01/2018 @ 12:00am (UTC)
        Sale 3%
        1546300800 == 01/01/2019 @ 12:00am (UTC)
        */

        // 50% 1M€ cap for Angels' Week
        if (buyTime < 1535760000){
            if (distributed < 25e6 * units){ // <25M tokens
                return (tokenBase * 150) / 100;
            } else {
                return (tokenBase * 112) / 100;
            }
        }
        // PRE-SALE. Bonus 12%
        else if (buyTime < 1538352000){
            if (distributed < 125e6 * units){ // <125M tokens
                return (tokenBase * 112) / 100;
            } else {
                return (tokenBase * 109) / 100;
            }
        }
        // TOKEN SALE.
        else if ((buyTime < 1546300800) && (distributed + tokenBase < 425e6 * units)) {
            /* GREAT DISCOUNT FOR GREAT INVESTORS */
            if (tokenBase > 375000 * units) {
                if (tokenBase > 750000 * units) {
                    return (tokenBase * 116) / 100;  // 75k e
                }
                if (tokenBase > 1500000 * units) {
                    return (tokenBase * 118) / 100;  // 150k e
                }

                return (tokenBase * 114) / 100; // 37k e
            }

            if (buyTime < 1541030400){ // Stage 1
                return (tokenBase * 109) / 100;
            }
            if (buyTime < 1543622400){ // Stage 2
                return (tokenBase * 106) / 100;
            }

            return (tokenBase * 103) / 100; // Stage 3
        }
    }

    function deposit() external payable onlyOwner returns(bool success) {
        assert (address(this).balance + msg.value >= address(this).balance); // Check for overflows
        tokenReward = address(this).balance / distributed;

        //executes event to reflect the changes
        emit LogDeposit(msg.sender, msg.value);
        return true;
    }

    function buy() public payable {
        require(distributed < maxSupply);
        require(block.timestamp < timeEndSale);

        uint256 tokenAmount = tokensDelivered();
        transferBuy(msg.sender, tokenAmount);

        itinyAddr.transfer(msg.value);
    }

    function transferBuy(address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));

        distributed = distributed.add(_value);
        if (block.timestamp < 1535760000) holdUntil[_to] = 1567296000; // 12mo 09/01/2019 @ 12:00am (UTC)
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
        require(block.timestamp <= timeEndSale || msg.sender == owner);
        uint256 _amount;
        if (owner == msg.sender) {
            _amount = balances[_addr];
            balances[_addr] = 0;
            balancesLocked[_addr] = balancesLocked[_addr].add(_amount);
            balances[0] = balances[0].add(_amount);
            emit ReserveFunds(_addr, _amount);
        } else {
            require(holdUntil[msg.sender] == 0);
            _amount = balances[msg.sender];
            require(_amount > 370000 * units);
            balances[msg.sender] = 0;
            balancesLocked[msg.sender] = balancesLocked[msg.sender].add(_amount);
            balances[0] = balances[0].add(_amount);
            emit ReserveFunds(msg.sender, _amount);
        }
    }

    function kyc(address _addr) external onlyOwner {
        isKyc[_addr] = 1;
        emit knownCustomer(_addr);
    }
}
