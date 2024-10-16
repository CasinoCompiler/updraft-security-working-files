// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Registry} from "../../../src/Registry.sol";

contract RegistryTest is Test {
    Registry registry;
    address alice;

    function setUp() public {
        alice = makeAddr("alice");
        
        registry = new Registry();
    }

    function test_MsgValueSent(uint256 _value) public {

        // If _value < PRICE, revert
        // If _value = PRICE, register
        // If _value > PRICE, register + return change
        _value = bound(_value, 0, 10e18);
        vm.deal(alice, _value);

        uint256 initialBalance = address(registry).balance;
        uint256 aliceInitialBalance = alice.balance;

        if (_value < registry.PRICE()){
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(Registry.PaymentNotEnough.selector, registry.PRICE(), _value));
            registry.register{value: _value}();
        } else {
            vm.prank(alice);
            registry.register{value: _value}();

            // Check if registered
            assertTrue(registry.isRegistered(alice));
            console2.log("Alice registered");

            // Assert contract took all of _value
            assertEq(address(registry).balance, initialBalance + _value);
            console2.log("Contract balance: ", address(registry).balance);
            console2.log("_value: ", _value);

            // Check Alice's balance and show she lost all of _value
            console2.log("Alice initial balance: ", aliceInitialBalance);
            console2.log("Alice final balance: ", alice.balance);
            console2.log("Alice expected balance: ", aliceInitialBalance - registry.PRICE());
            assertEq(alice.balance, aliceInitialBalance - registry.PRICE());
        }
    }
}