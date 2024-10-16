// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");
    address anotherUser = makeAddr("anotherUser");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 2000e18);
        poolToken.mint(liquidityProvider, 2000e18);

        weth.mint(user, 1000e18);
        poolToken.mint(user, 1000e18);

        weth.mint(anotherUser, 1000e18);
        poolToken.mint(anotherUser, 1000e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + poolToken.balanceOf(liquidityProvider) > 400e18);
    }

    /*//////////////////////////////////////////////////////////////
                           PROOF OF CONCEPTS
    //////////////////////////////////////////////////////////////*/
    // Provide initial liquidity to pool
    modifier provideInitialLiquidity {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();
        _;
    }

    // Approve tokens to TSwapPool for user
    modifier userGivesApproval {
        vm.startPrank(user);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();
        _;
    }

    // Approve tokens to TSwapPool for user
    modifier anotherUserGivesApproval {
        vm.startPrank(anotherUser);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();
        _;
    }

    function test_Low_2() public provideInitialLiquidity userGivesApproval {   
        vm.startPrank(user);
        uint256 outputReturn = pool.swapExactInput(poolToken, 1e18, weth, 1e9, uint64(block.timestamp));

        assert(outputReturn == 0);
    }

    // 10131404313951956880
    // 1013140431395195688
    function test_High_2() public provideInitialLiquidity {
        uint256 expectedInputReturn = ((poolToken.balanceOf(address(pool)) * 1e18) * 1000) / ((weth.balanceOf(address(pool)) - 1e18) * 997);

        vm.startPrank(user);
        uint256 inputReturn = pool.getInputAmountBasedOnOutput(1e18, poolToken.balanceOf(address(pool)), weth.balanceOf(address(pool)));

        assert(expectedInputReturn != inputReturn);
    }

    function test_High_3() public provideInitialLiquidity userGivesApproval anotherUserGivesApproval{
        uint64 warpedTimestamp = uint64(block.timestamp) + 10000;

        // 10_131_404_313_951_956_880
        // 23_829_403_655_175_811_218

        vm.warp(warpedTimestamp);
        vm.startPrank(anotherUser);
        pool.swapExactOutput(poolToken, weth, 10e18, warpedTimestamp);
        vm.stopPrank();
        vm.startPrank(user);
        uint256 actualInputAmount = pool.swapExactOutput(poolToken, weth, 1e18, warpedTimestamp);
        console.log(actualInputAmount);
        vm.stopPrank();
    }

    function test_High_4() public provideInitialLiquidity {

    }
}
