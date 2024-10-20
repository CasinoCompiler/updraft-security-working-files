// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

interface ITSwapPool {
    // @followup :: Is token address not supposed to be passed in?
    function getPriceOfOnePoolTokenInWeth() external view returns (uint256);
}
