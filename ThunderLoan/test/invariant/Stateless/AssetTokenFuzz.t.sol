// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

contract AssetTokenFuzz is Test {

    uint256 public s_exchangeRate;
    uint256 public startingExchangeRate;
    uint256 public endingExchangeRate;
    uint256 public constant STARTING_EXCHANGE_RATE = 1e18;
    uint256 public s_startingSupply = 1e18;

    function setUp() public {
        s_exchangeRate = STARTING_EXCHANGE_RATE;
    }

        function test_fixedUpdate(uint256 fee) public {
        console.log("hi");
        fee = bound(fee, 0, 1000e18);
        console.log("Fee: ", fee);

        
        startingExchangeRate = getExchangeRate();

        uint256 newExchangeRate = startingExchangeRate * (s_startingSupply + fee) / s_startingSupply;

        endingExchangeRate = newExchangeRate;
        s_exchangeRate = newExchangeRate;
    }

    /*//////////////////////////////////////////////////////////////
                             HELPER GETTERS
    //////////////////////////////////////////////////////////////*/

    function getExchangeRate() public view returns(uint256){
        return s_exchangeRate;
    }
}