// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.7.6;

contract SelfDestruct {

    address payable addressToForceEthReceive;

    constructor(address _addressToForceEthReceive) {
        addressToForceEthReceive = payable(_addressToForceEthReceive);
    }

    function destructAndSendEth() public {
        require(addressToForceEthReceive.balance > 0);

        selfdestruct(addressToForceEthReceive);
    }

}