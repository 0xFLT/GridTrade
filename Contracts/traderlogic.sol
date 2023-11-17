// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TraderLogic {
    ISwapRouter public immutable uniswapRouter;
    AggregatorV3Interface public immutable priceFeed;
    AggregatorV3Interface public immutable gasPriceFeed;
    IERC20 public immutable usdtToken;
    IERC20 public immutable wethToken;

    // Constants for trading
    uint256 public constant MAX_GAS_COST_USD = 40 * 1e18; // $40 with 18 decimals
    uint256 public constant SLIPPAGE_TOLERANCE = 200; // 2% slippage tolerance
    uint24 public constant POOL_FEE = 3000; // 0.3% pool fee

    // State variables
    mapping(address => uint256) public initialDeposits;
    mapping(address => uint256) public initialPrices;
    mapping(address => uint256) public lastTradeBlock;

    // Events
    event TradeInitiated(address indexed user, bool isBuy, uint256 amountETH, uint256 amountUSDT);

    constructor(
        address _priceFeed,
        address _gasPriceFeed,
        address _uniswapRouter,
        address _usdtToken,
        address _wethToken
    ) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        gasPriceFeed = AggregatorV3Interface(_gasPriceFeed);
        uniswapRouter = ISwapRouter(_uniswapRouter);
        usdtToken = IERC20(_usdtToken);
        wethToken = IERC20(_wethToken);
    }

    // Function to execute a trade if it's profitable
    function initiateTrade(address depositor, uint256 depositAmountETH) external {
        require(initialDeposits[depositor] > 0, "No initial deposit recorded for this address");
        require(block.number >= lastTradeBlock[depositor] + 1000, "Not enough blocks have passed since the last trade");

        uint256 currentPrice = getCurrentETHPrice();
        uint256 initialPrice = initialPrices[depositor];
        uint256 tradeAmountETH = (initialDeposits[depositor] * TRADE_PERCENTAGE) / 100;

        // Check the profitability of the trade
        bool isBuy = currentPrice < initialPrice;
        uint256 priceDifference = isBuy ? initialPrice - currentPrice : currentPrice - initialPrice;
        uint256 profitMargin = priceDifference * tradeAmountETH;

        // Estimate gas costs
        uint256 gasCost = estimateGasCost();
        require(profitMargin > gasCost, "Trade is not profitable after gas costs");

        // Calculate the minimum amount out to handle slippage
        uint256 amountOutMinimum = isBuy ? 
            (tradeAmountETH * currentPrice * (10000 - SLIPPAGE_TOLERANCE)) / 1e6 : 
            (tradeAmountETH * (10000 - SLIPPAGE_TOLERANCE)) / 10000;

        // Execute the trade
        uint256 amountOut = performSwap(depositor, isBuy, tradeAmountETH, amountOutMinimum);

        emit TradeInitiated(depositor, isBuy, tradeAmountETH, amountOut);
        lastTradeBlock[depositor] = block.number;
    }

    // Helper function to perform the swap on Uniswap V3
    function performSwap(
        address depositor,
        bool isBuy,
        uint256 tradeAmountETH,
        uint256 amountOutMinimum
    ) private returns (uint256 amountOut) {
        // Prepare parameters for the swap
        address tokenIn = isBuy ? address(usdtToken) : address(wethToken);
        address tokenOut = isBuy ? address(wethToken) : address(usdtToken);
        uint256 deadline = block.timestamp + 15; // 15 seconds from the current block timestamp

        // Approve token transfer to Uniswap router
        IERC20(tokenIn).approve(address(uniswapRouter), tradeAmountETH);

        // Perform the swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: POOL_FEE,
            recipient: depositor,
            deadline: deadline,
            amountIn: tradeAmountETH,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        amountOut = uniswapRouter.exactInputSingle(params);
        return amountOut;
    }

    // Helper function to get the current ETH price in USD
    function getCurrentETHPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) * 1e10; // Adjusting to 18 decimal places
    }

    // Helper function to estimate the gas cost
    function estimateGasCost() public view returns (uint256 gasCostUSD) {
        (, int256 gasPrice, , , ) = gasPriceFeed.latestRoundData();
        uint256 gasPriceWei = uint256(gasPrice) * 1e9; // Convert gwei to wei
        uint256 ethPriceUSD = getCurrentETHPrice();
        uint256 estimatedGas = GAS_ESTIMATE * gasPriceWei;
        gasCostUSD = (estimatedGas * ethPriceUSD) / 1e18;
        return gasCostUSD;
    }
}
