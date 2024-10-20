// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AssetToken} from "../../../src/protocol/AssetToken.sol";
import {Test, console} from "../.../../../../lib/forge-std/src/Test.sol";

contract Handler is Test{
    AssetToken public i_assetToken;
    address public i_assetTokenAddress;
    address public i_thunderLoanAccessAddress;

    // Ghost Variables
    uint256 public s_exchangeRate;
    uint256 public startingExchangeRate;
    uint256 public endingExchangeRate;
    uint256 public constant STARTING_EXCHANGE_RATE = 1e18;

    constructor (AssetToken _assetToken, address _thunderLoanAccessAddress) {
        require(address(_assetToken) != address(0), "AssetToken address cannot be zero");
        require(_thunderLoanAccessAddress != address(0), "ThunderLoan address cannot be zero");
    
        i_assetToken = _assetToken;
        i_assetTokenAddress = address(_assetToken);
        i_thunderLoanAccessAddress = _thunderLoanAccessAddress;
        s_exchangeRate = STARTING_EXCHANGE_RATE;
        startingExchangeRate = STARTING_EXCHANGE_RATE;
        endingExchangeRate = STARTING_EXCHANGE_RATE;
    }

    // function ghostUpdateExchangeRate(uint256 fee) public {
    //     // Bound the fee <= testing variable
    //     fee = bound(fee, 0, type(uint256).max);

    //     // Get starting exchange rate
    //     startingExchangeRate = i_assetToken.getExchangeRate();

    //     // Update Exchange rate
    //     vm.startPrank(i_thunderLoanAccessAddress);
    //     i_assetToken.updateExchangeRate(fee);
    //     vm.stopPrank();

    //     // Get new exchange rate and update ghost exchangeRate
    //     endingExchangeRate = i_assetToken.getExchangeRate();
    // }

    function fixedUpdate(uint256 fee) public {
        console.log("hi");
        fee = bound(fee, 0, 1000e18);

        uint256 startingSupply = 1e18;
        startingExchangeRate = getExchangeRate();

        uint256 newExchangeRate = startingExchangeRate * (startingSupply + fee) / startingSupply;

        endingExchangeRate = newExchangeRate;
        s_exchangeRate = newExchangeRate;

        console.log("Fixed update performed. Start:", startingExchangeRate, "End:", endingExchangeRate);
    }

    /*//////////////////////////////////////////////////////////////
                             HELPER GETTERS
    //////////////////////////////////////////////////////////////*/

    function getExchangeRate() public view returns(uint256){
        return s_exchangeRate;
    }


}