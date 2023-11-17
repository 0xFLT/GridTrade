// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./TraderLogic.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GridTrade is Ownable {
    AggregatorV3Interface public priceFeed;
    TraderLogic public traderLogic;
    IERC20 public usdtToken;

    uint256 public constant BLOCKS_TILL_WITHDRAWAL = 100000;
    mapping(address => uint256) public lastDepositBlock;
    mapping(address => uint256) public ethBalances;
    mapping(address => uint256) public usdtBalances;

    // Event to signal a deposit has been made
    event DepositReceived(address indexed depositor, uint256 amount, uint256 blockNumber);
    
    // Event to signal a trade has been executed
    event TradeExecuted(address indexed depositor, uint256 ethSold, uint256 usdtBought);
    
    // Event to signal a withdrawal has been made
    event WithdrawalMade(address indexed withdrawer, uint256 ethAmount, uint256 usdtAmount);

    constructor(address _priceFeed, address _traderLogic, address _usdtAddress) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        traderLogic = TraderLogic(_traderLogic);
        usdtToken = IERC20(_usdtAddress);
    }

    // Function to handle ETH deposits and execute initial trade
    function depositETH() external payable {
        require(msg.value > 0, "Cannot deposit 0 ETH");
        
        // Record the block number at the time of deposit
        lastDepositBlock[msg.sender] = block.number;
        ethBalances[msg.sender] += msg.value; // Update the depositor's ETH balance
        
        // Emit an event that a deposit has occurred
        emit DepositReceived(msg.sender, msg.value, block.number);
        
        // Convert half of the deposit to USDT through TraderLogic
        uint256 halfDeposit = msg.value / 2;
        // Assume TraderLogic trade function returns the amount of USDT bought
        uint256 usdtBought = traderLogic.trade{ value: halfDeposit }(address(this), address(usdtToken), halfDeposit);

        // Update the depositor's USDT balance
        usdtBalances[msg.sender] += usdtBought;
        
        // Emit a TradeExecuted event with the actual USDT bought amount
        emit TradeExecuted(msg.sender, halfDeposit, usdtBought);
    }

    // Function to withdraw funds (ETH and USDT)
    // 1% fee is taken on withdrawal and sent to the contract creator
    function withdrawFunds(uint256 ethAmount, uint256 usdtAmount) public {
        require(block.number >= lastDepositBlock[msg.sender] + BLOCKS_TILL_WITHDRAWAL, "Withdrawal is locked");
        require(ethAmount <= ethBalances[msg.sender], "Insufficient ETH balance");
        require(usdtAmount <= usdtBalances[msg.sender], "Insufficient USDT balance");
    
        // Calculate the 1% fee for the contract creator, round half up
        uint256 ethFee = (ethAmount + 50) / 100; // Add 50 before dividing by 100 to round half up
        uint256 usdtFee = (usdtAmount + 50) / 100; // Add 50 before dividing by 100 to round half up
    
        // Adjust the withdrawal amount to exclude the fee
        uint256 ethWithdrawalAmount = ethAmount - ethFee;
        uint256 usdtWithdrawalAmount = usdtAmount - usdtFee;
    
        // Transfer the fee to the contract creator
        if(ethFee > 0) {
            payable(owner()).transfer(ethFee);
        }
        
        if(usdtFee > 0) {
            usdtToken.transfer(owner(), usdtFee);
        }
    
        // Transfer the remaining funds to the withdrawer
        if(ethWithdrawalAmount > 0) {
            ethBalances[msg.sender] -= ethAmount;
            payable(msg.sender).transfer(ethWithdrawalAmount);
        }
        
        if(usdtWithdrawalAmount > 0) {
            usdtBalances[msg.sender] -= usdtAmount;
            usdtToken.transfer(msg.sender, usdtWithdrawalAmount);
        }
    
        // Emit a WithdrawalMade event
        emit WithdrawalMade(msg.sender, ethWithdrawalAmount, usdtWithdrawalAmount);
    }

}

