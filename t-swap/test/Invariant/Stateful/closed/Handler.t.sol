// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "../../../../lib/forge-std/src/Test.sol";
import {TSwapPool} from "../../../../src/TSwapPool.sol";
import {PoolFactory} from "../../../../src/PoolFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../../../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool tSwapPool;
    PoolFactory poolFactory;
    ERC20Mock weth;
    ERC20Mock poolToken;

    address public admin = makeAddr("admin");
    address initialLiquidityProvider = makeAddr("initialLiquidityProvider");
    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    // Our Ghost variables
    int256 public actualDeltaY;
    int256 public expectedDeltaY;

    int256 public actualDeltaX;
    int256 public expectedDeltaX;

    int256 public startingX;
    int256 public startingY;


    constructor (TSwapPool _tSwapPool, PoolFactory _poolFactory, ERC20Mock _weth, ERC20Mock _poolToken) {
        tSwapPool = _tSwapPool;
        poolFactory = _poolFactory;
        weth = _weth;
        poolToken = _poolToken;
    }

    // This will be the "initial" funding of the protocol. We are starting from blank here!
    // We just have them send the tokens in, and we mint liquidity tokens based on the weth
    function initialLiquidityProvision(uint256 initialWethLiquidity, uint256 initialTokenLiquidityRatio) public {
        if (weth.balanceOf(address(tSwapPool)) != 0) {
            return;
        }
        
        // Set initial liquidity
        initialWethLiquidity = bound(initialWethLiquidity, 5e18, 100e18);
        initialTokenLiquidityRatio = bound(initialTokenLiquidityRatio, 2, 10);
        uint256 initialTokenAmount = initialWethLiquidity * initialTokenLiquidityRatio;

        // Set initial liquidity tokens
        uint256 initialLiquidityTokens = initialWethLiquidity;

        // mint ERC20 and mockweth
        vm.startPrank(admin);
        weth.mint(initialLiquidityProvider, initialWethLiquidity);
        poolToken.mint(initialLiquidityProvider, initialTokenAmount);
        vm.stopPrank();

        // Give permissions to TSwapPool to transfer tokens to Pool contract
        vm.startPrank(initialLiquidityProvider);
        weth.approve(address(tSwapPool), initialWethLiquidity);
        poolToken.approve(address(tSwapPool), initialTokenAmount);
        vm.stopPrank();

        // Deposit inital Liquidity
        vm.startPrank(initialLiquidityProvider); 
        tSwapPool.deposit(
            initialWethLiquidity,
            initialLiquidityTokens,
            initialTokenAmount,
            uint64(block.timestamp)
        );
        vm.stopPrank();
    }

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWethAmount) public {
        if (weth.balanceOf(address(tSwapPool)) <= tSwapPool.getMinimumWethDepositAmount()) {
            return;
        }
        outputWethAmount = bound(outputWethAmount, tSwapPool.getMinimumWethDepositAmount(), weth.balanceOf(address(tSwapPool)));
        // If these two values are the same, we will divide by 0
        if (outputWethAmount == weth.balanceOf(address(tSwapPool))) {
            return;
        }
        uint256 poolTokenAmount = tSwapPool.getInputAmountBasedOnOutput(
            outputWethAmount, // outputAmount
            poolToken.balanceOf(address(tSwapPool)), // inputReserves
            weth.balanceOf(address(tSwapPool)) // outputReserves
        );
        if (poolTokenAmount > type(uint64).max) {
            return;
        }
        // We * -1 since we are removing WETH from the system
        _updateStartingDeltas(int256(outputWethAmount) * -1, int256(poolTokenAmount));

        // Mint any necessary amount of pool tokens
        if (poolToken.balanceOf(user) < poolTokenAmount) {
            poolToken.mint(user, poolTokenAmount - poolToken.balanceOf(user) + 1);
        }

        vm.startPrank(user);
        // Approve tokens so they can be pulled by the pool during the swap
        poolToken.approve(address(tSwapPool), type(uint256).max);

        // Execute swap, giving pool tokens, receiving WETH
        tSwapPool.swapExactOutput({
            inputToken: poolToken,
            outputToken: weth,
            outputAmount: outputWethAmount,
            deadline: uint64(block.timestamp)
        });
        vm.stopPrank();
        _updateEndingDeltas();
    }

    function deposit(uint256 wethAmountToDeposit) public {
        // make the amount to deposit a "reasonable" number. We wouldn't expect someone to have type(uint256).max WETH!!
        wethAmountToDeposit = bound(wethAmountToDeposit, tSwapPool.getMinimumWethDepositAmount(), type(uint64).max);
        uint256 amountPoolTokensToDepositBasedOnWeth = tSwapPool.getPoolTokensToDepositBasedOnWeth(wethAmountToDeposit);
        _updateStartingDeltas(int256(wethAmountToDeposit), int256(amountPoolTokensToDepositBasedOnWeth));

        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmountToDeposit);
        poolToken.mint(liquidityProvider, amountPoolTokensToDepositBasedOnWeth);

        weth.approve(address(tSwapPool), wethAmountToDeposit);
        poolToken.approve(address(tSwapPool), amountPoolTokensToDepositBasedOnWeth);

        tSwapPool.deposit({
            wethToDeposit: wethAmountToDeposit,
            minimumLiquidityTokensToMint: 0,
            maximumPoolTokensToDeposit: amountPoolTokensToDepositBasedOnWeth,
            deadline: uint64(block.timestamp)
        });
        vm.stopPrank();
        _updateEndingDeltas();
    }

    /*//////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _updateStartingDeltas(int256 wethAmount, int256 poolTokenAmount) internal {
        startingY = int256(poolToken.balanceOf(address(tSwapPool)));
        startingX = int256(weth.balanceOf(address(tSwapPool)));

        expectedDeltaX = wethAmount;
        expectedDeltaY = poolTokenAmount;
    }

    function _updateEndingDeltas() internal {
        uint256 endingPoolTokenBalance = poolToken.balanceOf(address(tSwapPool));
        uint256 endingWethBalance = weth.balanceOf(address(tSwapPool));

        // sell tokens == x == poolTokens
        int256 actualDeltaPoolToken = int256(endingPoolTokenBalance) - int256(startingY);
        int256 deltaWeth = int256(endingWethBalance) - int256(startingX);

        actualDeltaX = deltaWeth;
        actualDeltaY = actualDeltaPoolToken;
    }

}