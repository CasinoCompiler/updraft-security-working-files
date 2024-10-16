// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Registry {
    error PaymentNotEnough(uint256 expected, uint256 actual); // e revert for not enough

    uint256 public constant PRICE = 1 ether; // fee

    mapping(address account => bool registered) private registry; // mapping to see if registered

    function register() external payable {
        // no check for if registered

        if(msg.value < PRICE) {
            revert PaymentNotEnough(PRICE, msg.value);
        }

        // No check if msg.value > PRICE

        registry[msg.sender] = true;
    }

    function isRegistered(address account) external view returns (bool) {
        return registry[account];
    }
}