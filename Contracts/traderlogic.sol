// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TraderLogic {
    ISwapRouter public uniswapRouter;
    AggregatorV3Interface public priceFeed;
    IERC20 public usdtToken;

    // Address of the WETH token, which is needed for trading with Uniswap V3
    address public wethTokenAddress;

    // Constants for trading
    uint256 public constant GAS_ESTIMATE = 200000; // Example gas estimate for a trade
    uint256 public constant MAX_GAS_COST_USD = 40 * 1e18; // $40 with 18 decimals
    uint256 public constant TRADE_PERCENTAGE = 2; // Use 2% of the total deposited amount for trading

    // State variables
    mapping(address => uint256) public initialDeposits;
    mapping(address => uint256) public initialPrices;
    mapping(address => uint256) public lastTradeBlock;

    // Events
    event TradeInitiated(address indexed user, uint256 amountETH, uint256 amountUSDT);

    constructor(address _priceFeed, address _uniswapRouter, address _usdtToken, address _wethToken) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        uniswapRouter = ISwapRouter(_uniswapRouter);
        usdtToken = IERC20(_usdtToken);
        wethTokenAddress = _wethToken;
    }

    // Assume this function is called by the GridTrade contract when a new deposit is received
    function initiateTrade(address depositor, uint256 depositAmountETH) external {
        require(depositAmountETH > 0, "Deposit amount must be greater than zero");
        uint256 ethPriceUSD = getCurrentETHPrice();
        uint256 totalDepositUSD = (depositAmountETH * ethPriceUSD) / 1e18; // Convert deposit amount to USD

        // Record the deposit details
        initialDeposits[depositor] = depositAmountETH;
        initialPrices[depositor] = ethPriceUSD;
        lastTradeBlock[depositor] = block.number;

        // Sell 40% of ETH for USDT
        uint256 amountToSellETH = (depositAmountETH * 40) / 100;

        // Check if the estimated gas cost is less than $40
        uint256 estimatedGasCostETH = GAS_ESTIMATE * tx.gasprice;
        uint256 estimatedGasCostUSD = (estimatedGasCostETH * ethPriceUSD) / 1e18;
        require(estimatedGasCostUSD <= MAX_GAS_COST_USD, "Estimated gas cost exceeds $40 USD");

        // Implement the trade with Uniswap V3 here
        // This is a placeholder; actual Uniswap V3 swap logic should be used
        // For this example, we emit an event instead of performing a swap
        emit TradeInitiated(depositor, amountToSellETH, 0); // Replace 0 with actual USDT bought amount
    }

    // Helper function to get the current ETH price in USD
    function getCurrentETHPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

}

