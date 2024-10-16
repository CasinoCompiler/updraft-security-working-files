// SPDX-License-Identifier: UNLICENSED

/** 
 * @notice I believe the OPEN stateful test should catch the error
 */
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Registry} from "../../../src/Registry.sol";

contract RegistryTest is StdInvariant, Test {
    Registry registry;
    address alice;

    function setUp() public {
        alice = makeAddr("alice");
        
        registry = new Registry();
    }

    function invariant_CanReEnter() public {
        
    }
}