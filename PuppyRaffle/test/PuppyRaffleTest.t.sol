// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {Attack} from "../src/ReentrencyAttack.sol";
import {SelfDestruct} from "../src/SelfDestruct.sol";
import {Frontrun, FrontrunHelper} from "../src/Frontrun.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    Attack attack;
    SelfDestruct selfDestruct;
    Frontrun frontrun;
    FrontrunHelper frontrunHelper;

    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = makeAddr("feeAddress");
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );

        attack = new Attack(address(puppyRaffle));
        selfDestruct = new SelfDestruct(address(puppyRaffle));
        frontrunHelper = new FrontrunHelper(address(puppyRaffle));
        frontrun = new Frontrun(address(frontrunHelper));
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                               REENTRENCY
    //////////////////////////////////////////////////////////////*/
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function test_RefundReentrency() public {

        // ARGS for entering enterRaffle()
        address[] memory aliceARG = new address[](1);
        aliceARG[0] = alice;
        address[] memory bobARG = new address[](1);
        bobARG[0] = bob;

        // Fund Alice and bob and make them enter raffle
        vm.deal(alice, entranceFee * 2);
        vm.deal(bob, entranceFee * 2);
        vm.prank(alice);
        puppyRaffle.enterRaffle{value: entranceFee}(aliceARG);
        vm.prank(bob);
        puppyRaffle.enterRaffle{value: entranceFee}(bobARG);

        // Fund attack contract
        vm.deal(address(attack), 1 ether);
        attack.attack();

        console.log(address(attack).balance);

        assert(address(attack).balance > 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          TEST MULTIPLE TIMES
    //////////////////////////////////////////////////////////////*/
    address charlie = makeAddr("charlie");

    function test_CharlieEnterMultipleTime() public {
        // ARGS for entering enterRaffle()
        address[] memory charlieARG = new address[](2);
        charlieARG[0] = charlie;
        charlieARG[1] = charlie;

        vm.deal(charlie, entranceFee * 2);
        vm.prank(charlie);
        vm.expectRevert();
        puppyRaffle.enterRaffle{value: entranceFee * 2}(charlieARG);
    }

    /*//////////////////////////////////////////////////////////////
                               RANDOMNESS
    //////////////////////////////////////////////////////////////*/
    // not truly random + can be gamed + msg.sender used to find hash 

    address one = address(5);
    address two = address(6);
    address three = address(7);
    address four = address(8);
    address advisory = makeAddr("advisory");


    function test_Randomness() public {
        // Give the entrance fee * 4 to enter for all players
        vm.deal(one, entranceFee * 4);

        // Give advisory entrance
        vm.deal(advisory, entranceFee);

        // ARGS for entering enterRaffle()
        address[] memory playersARG = new address[](4);
        playersARG[0] = one;
        playersARG[1] = two;
        playersARG[2] = three;
        playersARG[3] = four;
        address[] memory advisoryARG = new address[](1);
        advisoryARG[0] = advisory; 

        vm.prank(one);
        puppyRaffle.enterRaffle{value: entranceFee * 4}(playersARG);

        // Fast forward to end of raffle
        uint256 raffleEndTime = block.timestamp + 1 weeks + 1;
        vm.warp(raffleEndTime);

        uint256 manipulatedPrevRandao;
        uint256 manipulatedTimestamp;
        uint256 manipulatedBlockNumber;

        // Simulate miner manipulation by trying different values
        for (uint i = 1; i < 1000; i++) {
            manipulatedPrevRandao = uint256(keccak256(abi.encodePacked(i)));
            manipulatedTimestamp = raffleEndTime + i;
            manipulatedBlockNumber = block.number + i;

            // Calculate the winnerIndex with manipulated values
            uint256 winnerIndex = uint256(keccak256(abi.encodePacked(advisory, manipulatedTimestamp, manipulatedPrevRandao))) % (playersARG.length + 1);

            // Break for loop if winnerIndex == advisory index
            if (winnerIndex == playersARG.length ){
                break;
            }
        }

        vm.startPrank(advisory);
        puppyRaffle.enterRaffle{value: 1 ether}(advisoryARG);
        vm.warp(manipulatedTimestamp);
        vm.roll(manipulatedBlockNumber);
        vm.prevrandao(manipulatedPrevRandao);
        puppyRaffle.selectWinner();
        vm.stopPrank();

        uint256 expectedPayout = ((entranceFee * 5) * 80 / 100);

        assertEq(puppyRaffle.previousWinner(), advisory);
        assertEq(advisory.balance, expectedPayout);
    }

    /*//////////////////////////////////////////////////////////////
                             CANT WITHDRAW
    //////////////////////////////////////////////////////////////*/
        
    function test_CantWithdraw() public {
        // Give the entrance fee * 4 to enter for all players
        vm.deal(one, entranceFee * 4);

        // Give advisory entrance
        vm.deal(advisory, entranceFee);

        // Fund Self destructing contract
        vm.deal(address(selfDestruct), 20 ether);

        // ARGS for entering enterRaffle()
        address[] memory playersARG = new address[](4);
        playersARG[0] = one;
        playersARG[1] = two;
        playersARG[2] = three;
        playersARG[3] = four;
        address[] memory advisoryARG = new address[](1);
        advisoryARG[0] = advisory; 

        vm.prank(one);
        puppyRaffle.enterRaffle{value: entranceFee * 4}(playersARG);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.startPrank(advisory);
        selfDestruct.destructAndSendEth();
        puppyRaffle.selectWinner();
        vm.expectRevert();
        puppyRaffle.withdrawFees();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                OVERFLOW
    //////////////////////////////////////////////////////////////*/
    

    /*//////////////////////////////////////////////////////////////
                                FRONTRUN
    //////////////////////////////////////////////////////////////*/
    address selectWinnerCaller = makeAddr("selectWinnerCaller");

    function test_Frontrun() public {

        // Give the entrance fee * 4 to enter for all players
        vm.deal(one, entranceFee * 4);

        // Supply Advisory, Frontrun & frontrun helper with Eth
        vm.deal(address(frontrunHelper), 10 ether);
        vm.deal(address(frontrun), 10 ether);
        vm.deal(advisory, 10 ether); 

        // ARGS for entering enterRaffle()
        address[] memory playersARG = new address[](4);
        playersARG[0] = one;
        playersARG[1] = two;
        playersARG[2] = three;
        playersARG[3] = four;

        // one enters raffle for everyone
        vm.prank(one);
        puppyRaffle.enterRaffle{value: entranceFee * 4}(playersARG);

        // BadActor enters raffle
        vm.prank(advisory);
        frontrunHelper.enter{value: entranceFee}();

        // Warp to when selectWinner() can be called
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        // Simulate frontrun
        vm.startPrank(selectWinnerCaller);
        frontrun.attack(selectWinnerCaller);
        puppyRaffle.selectWinner();
    }

}