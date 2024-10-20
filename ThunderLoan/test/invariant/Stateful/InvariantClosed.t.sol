// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {StdInvariant} from "../.../../../../lib/forge-std/src/StdInvariant.sol";
import {Test, console} from "../.../../../../lib/forge-std/src/Test.sol";
import {AssetToken} from "../../../src/protocol/AssetToken.sol";
import {Handler} from "./Handler.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InvariantClosed is StdInvariant, Test {
    AssetToken assetToken;
    Handler handler;

    address admin = makeAddr("admin");

    // assetToken Constructor Args
    address thunderLoanDummyAddress = makeAddr("thunderLoanDummyAddress");
    address underlyingDummyAddress = makeAddr("underlyingDummyAddress");
    string assetName = "Test";
    string assetSymbol = "TEST";

    function setUp() public {
        vm.startPrank(thunderLoanDummyAddress);
        try new AssetToken(thunderLoanDummyAddress, IERC20(underlyingDummyAddress), assetName, assetSymbol) returns (AssetToken _assetToken) {
            assetToken = _assetToken;
            console.log("AssetToken deployed successfully");
        } catch Error(string memory reason) {
            console.log("AssetToken deployment failed:", reason);
            revert("AssetToken deployment failed");
        }
        vm.stopPrank();

        try new Handler(assetToken, thunderLoanDummyAddress) returns (Handler _handler) {
            handler = _handler;
            console.log("Handler deployed successfully");
        } catch Error(string memory reason) {
            console.log("Handler deployment failed:", reason);
            revert("Handler deployment failed");
        }

        // Create targetSelectorsArg
        bytes4[] memory selectorsArg = new bytes4[](1);
        selectorsArg[0] = Handler.fixedUpdate.selector;

        targetContract(address(handler));

        // Do an initial run
        handler.fixedUpdate(1);

        // targetSelector(FuzzSelector({addr: address(handler), selectors: selectorsArg}));
        console.log("setUp() complete");
        console.log(handler.startingExchangeRate());
    }

    function invariant_testRunning() public pure{
        console.log("Invariant test is running");
        assert(true);
    }

    function invariant_handlerAccessible() public view {
        console.log("Accessing handler");
        uint256 rate = handler.getExchangeRate();
        console.log("Current exchange rate:", rate);
        assert(rate > 0);
    }

    function invariant_fixedUpdateWorks() public {
        console.log("Before fixedUpdate");
        uint256 before = handler.getExchangeRate();
        console.log("Exchange rate before:", before);

        handler.fixedUpdate(100e18);

        console.log("After fixedUpdate");
        uint256 afterFU = handler.getExchangeRate();
        console.log("Exchange rate after:", afterFU);

        assert(afterFU > before);
    }

    function invariant_ExchangeRateAlwaysGoesUp() public view {
        uint256 starting = handler.startingExchangeRate();
        uint256 ending = handler.endingExchangeRate();
        
        // Only assert if at least one operation has been performed
        if (starting != 0 || ending != 0) {
            console.log("Starting Exchange Rate:", starting);
            console.log("Ending Exchange Rate:", ending);
            if (ending <= starting) {
                console.log("Invariant violated: Exchange rate did not increase");
                console.log("Starting:", starting);
                console.log("Ending:", ending);
            }
            assert(ending > starting);
        } else {
            console.log("No operations performed yet");
        }
    }
}