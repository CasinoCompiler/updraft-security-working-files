// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "../../../../lib/forge-std/src/Test.sol";
import {StdInvariant} from "../../../../lib/forge-std/src/StdInvariant.sol";
import {Handler} from "./Handler.t.sol";
import {TSwapPool} from "../../../../src/TSwapPool.sol";
import {PoolFactory} from "../../../../src/PoolFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../../../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract InvariantClosed is StdInvariant, Test {
    TSwapPool tSwapPool;
    PoolFactory poolFactory;
    Handler handler;
    IERC20 weth;
    ERC20Mock poolToken;
    ERC20Mock weth2;

    address public admin = makeAddr("admin");
    address public user_1 = makeAddr("user_1");

    function setUp() public {

        vm.startPrank(admin);
        poolToken = new ERC20Mock();
        weth2 = new ERC20Mock();
        poolFactory = new PoolFactory(address(weth2));
        tSwapPool = TSwapPool(poolFactory.createPool(address(poolToken)));
        vm.stopPrank();
        
        // Create handler and target selectors
        handler = new Handler(tSwapPool, poolFactory, weth2, poolToken);

        bytes4[] memory selectorsArg = new bytes4[](1);
        selectorsArg[0] = Handler.initialLiquidityProvision.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectorsArg}));
        excludeContract(address(poolToken));
        excludeContract(address(weth2));
    }

    function invariant_deltaXFollowsMath() public view {
        assertEq(handler.actualDeltaX(), handler.expectedDeltaX());
    }

    function invariant_deltaYFollowsMath() public view {
        assertEq(handler.actualDeltaY(), handler.expectedDeltaY());
    }
}