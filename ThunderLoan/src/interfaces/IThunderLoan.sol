// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IThunderLoan {
    // @audit - low :: not implemented correctly in ThunderLoan.sol
    function repay(address token, uint256 amount) external;
}
