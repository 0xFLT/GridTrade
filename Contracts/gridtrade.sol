// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./TraderLogic.sol"; // Importing the TraderLogic contract
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GridTrade is Ownable {
    AggregatorV3Interface public priceFeed;
    IERC20 public usdtToken;
    TraderLogic public traderLogic; // Instance of the TraderLogic contract

    uint256 public constant MINIMUM_DEPOSIT_USD = 10000 * 1e18; // $10k with 18 decimals
    uint256 public constant BLOCKS_TILL_WITHDRAWAL = 100000;
    mapping(address => uint256) public lastDepositBlock;
    mapping(address => uint256) public ethBalances;

    // Events
    event DepositReceived(address indexed depositor, uint256 ethAmount, uint256 blockNumber);
    event InsufficientDeposit(address indexed depositor, uint256 ethAmount);
    event FullWithdrawal(address indexed depositor, uint256 ethWithdrawn, uint256 ethFee);
    event InsufficientFundsHandled(address indexed handler, address to, uint256 amount);

    constructor(address _priceFeed, address _usdtAddress, address _traderLogicAddress) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        usdtToken = IERC20(_usdtAddress);
        traderLogic = TraderLogic(_traderLogicAddress); // Initialize the TraderLogic instance
    }

    // Fallback function to handle ETH deposits
    receive() external payable {
        uint256 usdValue = getUSDValue(msg.value);
        if (usdValue >= MINIMUM_DEPOSIT_USD) {
            lastDepositBlock[msg.sender] = block.number;
            ethBalances[msg.sender] += msg.value;
            emit DepositReceived(msg.sender, msg.value, block.number);
            // Call to the trading logic will be here
        } else {
            emit InsufficientDeposit(msg.sender, msg.value);
        }
    }

    // Helper function to get the USD value of the deposited ETH
    function getUSDValue(uint256 ethAmount) public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // Convert price to uint256 for safe multiplication
        // Assuming the price feed uses 8 decimals, adjust to match ETH's 18 decimals
        return (ethAmount * uint256(price)) / 1e8;
    }

    // Withdrawal function to allow depositors to withdraw their full balances
    function withdrawFullBalance() public {
        require(block.number >= lastDepositBlock[msg.sender] + BLOCKS_TILL_WITHDRAWAL, "Withdrawal is locked");

        uint256 depositorEthBalance = ethBalances[msg.sender];
        require(depositorEthBalance > 0, "No ETH balance to withdraw");

        uint256 ethFee = depositorEthBalance / 100;
        uint256 ethWithdrawalAmount = depositorEthBalance - ethFee;

        // Reset the depositor's balance to zero
        ethBalances[msg.sender] = 0;

        // Transfer the fee to the owner
        if (ethFee > 0) {
            payable(owner()).transfer(ethFee);
        }

        // Transfer the remaining balance to the depositor
        if (ethWithdrawalAmount > 0) {
            payable(msg.sender).transfer(ethWithdrawalAmount);
        }

        emit FullWithdrawal(msg.sender, ethWithdrawalAmount, ethFee);
    }

    // Function for the owner to handle ETH that was sent as an insufficient deposit
    function handleInsufficientDeposit(address payable to, uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance in contract");
        to.transfer(amount);
        emit InsufficientFundsHandled(msg.sender, to, amount);
    }
}
