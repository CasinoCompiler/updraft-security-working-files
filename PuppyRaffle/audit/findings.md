
### [H-1] Reentrency in `PuppyRaffle.sol:refund()` allowing for total contract drainage.

**Description:** 

`PuppyRaffle.sol::refund()` does not follow the [CEI](https://detectors.auditbase.com/checks-effects-interactions) function implementation structure, and as a result, a reentrency vector is introduced. 

when `PuppyRaffle.sol::refund()` is called, it [sends the refund via an external call](https://github.com/Cyfrin/4-puppy-raffle-audit/blob/15c50ec22382bb1f3106aba660e7c590df18dcac/src/PuppyRaffle.sol#L101) to the user index before [state is updated](https://github.com/Cyfrin/4-puppy-raffle-audit/blob/15c50ec22382bb1f3106aba660e7c590df18dcac/src/PuppyRaffle.sol#L103) i.e. removing the player from the raffle.

**Impact:**

Total drainage of  `PuppyRaffle.sol` contract.

**Proof of Concept:**
A bad actor can create an attack contract with a `receive()/fallback()` function that will

 1. Enter so it is in the raffle system and then
 2. Repeatedly call `PuppyRaffle.sol::refund()` until the contract is drained.

**Recommended Mitigation:**

To prevent this, we should have the `PuppyRaffle.sol::refund()` function update the `PuppyRaffle.sol::players` array before making the external call. Additionally, the event emissions should also be moved up.

<details>
<summary> Modification to <code>PuppyRaffle.sol::refund()</code> </summary>

```diff
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

+       players[playerIndex] = address(0);
+       emit RaffleRefunded(playerAddress);

        payable(msg.sender).sendValue(entranceFee);

-       players[playerIndex] = address(0);
-       emit RaffleRefunded(playerAddress);
    }
```
</details>

### [H-2] Weak randomness for `PuppyRaffle.sol::selectWinner()`, the winner can be easily gamed.

**Description:** 

The raffle system can be gamed as using `msg.sender`, `block.timestamp` and `block.difficulty` as a means to generate a random number is flawed as all 3 variables can easily be manipulated by a node validator, a player or a player working with a validator.

**Impact:**

Both the winner and the NFT rarity are determined using this pseudo-randomness, thus the system can be gamed so that a bad actor will only enter if they can guarantee:
a. their winnings 
b. a rare NFT

**Proof of Concept:**

1. A bad actor will calulate the winner with manipulated `msg.sender`, `block.timestamp` and `block.difficulty`.
2. They will enter the raffle when they believe is optimal timing
3. call `PuppyRaffle.sol::selectWinner()` and win the raffle


**Recommended Mitigation:** 

Consider using [Chainlink VRF](https://docs.chain.link/vrf), a proveable random seed generator.


### [H-3] Frontrunning `PuppyRaffle.sol::selectWinner()` in the case of an unfavourable outcome

**Description:** 

As a result of the pseudo-randomness, `PuppyRaffle.sol::selectWinner()` can be frontrun for multiple reasons:

1. raffle winner was not the bad actor therefore they refund their entry
2. raffle winner did not win a rare NFT therefore they refund their entry

**Impact:** 

Integrity of the raffle is compromised. Additionally, the raffle may never actually conclude if every entree were running a script to check for unfavourable outcomes.

**Proof of Concept:**

**Recommended Mitigation:** 

### [H-4] Arithmatic overflow of `PuppyRaffle::totalFees` loses fees.

**Description:** 

Prior to solidity `0.8.0`, arithmatic overflow could occur if the value were to surpass the maximum value for the casted type.

<details>
<summary> Example </summary>

```javascript
    uint64 myVar = type(uint64).max; //18446744073709551615
    myVar += 1; // Expected value 18446744073709551616 | Actual value: 0

```

</details>

**Impact:** 

The `totalFees` are accumulated using this [expression [1]](https://github.com/Cyfrin/4-puppy-raffle-audit/blob/15c50ec22382bb1f3106aba660e7c590df18dcac/src/PuppyRaffle.sol#L134) and totalFees itself is of type uint64; uint64 is considered small and could easily overflow, thus the incorrect fees would be collected by the `feeAddress`.

**Proof of Concept:**

1. Assume the `entranceFee` is `30 ether`.
2. If 4 players were to enter the raffle, using [1], the `totalFees` would be calculated as: 
   
   $\text{totalFees}_\text{Expected} = ((30e18 * 4) * 20 ) / 100$

   $\text{totalFees}_\text{Expected} = 24e18$

3. However, the actual totalFees will be a different value due to the overflow.
   
   $\text{totalFess}_\text{Actual} = 5553255926290448384$ 

   $\text{totalFess}_\text{Actual} \approxeq 55.53e17$

4. As a result, you will not be able to withdraw the totalFees as you will not pass the first check in `PuppyRaffle::withdrawFees()`.
   
**Recommended Mitigation:**

1. Use a newer version on solidity which has SafeMath built in by default. If solc `<0.8.0` is still being used, Safemath can be imported and used to safeguard from overflow.
2. Use a larger type of uint i.e. `uint256`.

### [M-1] The fees accrued can be stuck in the contract indefinitely due to a strict equality check in `PuppyRaffle.sol::withdrawFunds()`

**Description:** The `PuppyRaffle::withdrawFees` function checks the `totalFees` equals the ETH balance of the contract (`address(this).balance`). Since this contract doesn't have a `payable` fallback or `receive` function, you'd think this wouldn't be possible, but a user could `selfdesctruct` a contract with ETH in it and force funds to the `PuppyRaffle` contract, breaking this check. 

```javascript
    function withdrawFees() external {
@>      require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        (bool success,) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
    }
```

**Impact:** This would prevent the `feeAddress` from withdrawing fees. A malicious user could see a `withdrawFee` transaction in the mempool, front-run it, and block the withdrawal by sending fees. 

**Proof of Concept:**

1. `PuppyRaffle` has 800 wei in it's balance, and 800 totalFees.
2. Malicious user sends 1 wei via a `selfdestruct`
3. `feeAddress` is no longer able to withdraw funds

**Recommended Mitigation:** Remove the balance check on the `PuppyRaffle::withdrawFees` function. 

```diff
    function withdrawFees() external {
-       require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        (bool success,) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
    }
```


### [M-2] Denial of Service

**Description:** The `PuppyRaffle::enterRaffle` function loops through the `players` array to check for duplicates. However, the longer the `PuppyRaffle:players` array is, the more checks a new player will have to make. This means that the gas costs for players who enter right when the raffle starts will be dramatically lower than those who enter later. Every additional address in the `players` array, is an additional check the loop will have to make. 

**Note to students: This next line would likely be it's own finding itself. However, we haven't taught you about MEV yet, so we are going to ignore it.**
Additionally, this increased gas cost creates front-running opportunities where malicious users can front-run another raffle entrant's transaction, increasing its costs, so their enter transaction fails. 

**Impact:** The impact is two-fold.

1. The gas costs for raffle entrants will greatly increase as more players enter the raffle.
2. Front-running opportunities are created for malicious users to increase the gas costs of other users, so their transaction fails.

**Proof of Concept:** 

If we have 2 sets of 100 players enter, the gas costs will be as such:
- 1st 100 players: 6252039
- 2nd 100 players: 18067741

This is more than 3x as expensive for the second set of 100 players! 

This is due to the for loop in the `PuppyRaffle::enterRaffle` function. 

```javascript
        // Check for duplicates
@>      for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
```

<details>
<summary>Proof Of Code</summary>
Place the following test into `PuppyRaffleTest.t.sol`.

```javascript
function testReadDuplicateGasCosts() public {
        vm.txGasPrice(1);

        // We will enter 5 players into the raffle
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }
        // And see how much gas it cost to enter
        uint256 gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(players);
        uint256 gasEnd = gasleft();
        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas cost of the 1st 100 players:", gasUsedFirst);

        // We will enter 5 more players into the raffle
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i + playersNum);
        }
        // And see how much more expensive it is
        gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(players);
        gasEnd = gasleft();
        uint256 gasUsedSecond = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas cost of the 2nd 100 players:", gasUsedSecond);

        assert(gasUsedFirst < gasUsedSecond);
        // Logs:
        //     Gas cost of the 1st 100 players: 6252039
        //     Gas cost of the 2nd 100 players: 18067741
}
```
</details>

**Recommended Mitigation:** There are a few recommended mitigations.

1. Consider allowing duplicates. Users can make new wallet addresses anyways, so a duplicate check doesn't prevent the same person from entering multiple times, only the same wallet address.
2. Consider using a mapping to check duplicates. This would allow you to check for duplicates in constant time, rather than linear time. You could have each raffle have a `uint256` id, and the mapping would be a player address mapped to the raffle Id. 

```diff
+    mapping(address => uint256) public addressToRaffleId;
+    uint256 public raffleId = 0;
    .
    .
    .
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
+            addressToRaffleId[newPlayers[i]] = raffleId;            
        }

-        // Check for duplicates
+       // Check for duplicates only from the new players
+       for (uint256 i = 0; i < newPlayers.length; i++) {
+          require(addressToRaffleId[newPlayers[i]] != raffleId, "PuppyRaffle: Duplicate player");
+       }    
-        for (uint256 i = 0; i < players.length; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
-                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-            }
-        }
        emit RaffleEnter(newPlayers);
    }
.
.
.
    function selectWinner() external {
+       raffleId = raffleId + 1;
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
```

Alternatively, you could use [OpenZeppelin's `EnumerableSet` library](https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet).


### [M-3] Unsafe cast of `PuppyRaffle::fee` loses fees

**Description:** In `PuppyRaffle::selectWinner` their is a type cast of a `uint256` to a `uint64`. This is an unsafe cast, and if the `uint256` is larger than `type(uint64).max`, the value will be truncated. 

```javascript
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length > 0, "PuppyRaffle: No players in raffle");

        uint256 winnerIndex = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 fee = totalFees / 10;
        uint256 winnings = address(this).balance - fee;
@>      totalFees = totalFees + uint64(fee);
        players = new address[](0);
        emit RaffleWinner(winner, winnings);
    }
```

The max value of a `uint64` is `18446744073709551615`. In terms of ETH, this is only ~`18` ETH. Meaning, if more than 18ETH of fees are collected, the `fee` casting will truncate the value. 

**Impact:** This means the `feeAddress` will not collect the correct amount of fees, leaving fees permanently stuck in the contract.

**Proof of Concept:** 

1. A raffle proceeds with a little more than 18 ETH worth of fees collected
2. The line that casts the `fee` as a `uint64` hits
3. `totalFees` is incorrectly updated with a lower amount

You can replicate this in foundry's chisel by running the following:

```javascript
uint256 max = type(uint64).max
uint256 fee = max + 1
uint64(fee)
// prints 0
```

**Recommended Mitigation:** Set `PuppyRaffle::totalFees` to a `uint256` instead of a `uint64`, and remove the casting. Their is a comment which says:

```javascript
// We do some storage packing to save gas
```
But the potential gas saved isn't worth it if we have to recast and this bug exists. 

```diff
-   uint64 public totalFees = 0;
+   uint256 public totalFees = 0;
.
.
.
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 totalAmountCollected = players.length * entranceFee;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
-       totalFees = totalFees + uint64(fee);
+       totalFees = totalFees + fee;
```
### [M-4] Smart Contract wallet raffle winners without a `receive` or a `fallback` will block the start of a new contest

**Description:** The `PuppyRaffle::selectWinner` function is responsible for resetting the lottery. However, if the winner is a smart contract wallet that rejects payment, the lottery would not be able to restart. 

Non-smart contract wallet users could reenter, but it might cost them a lot of gas due to the duplicate check.

**Impact:** The `PuppyRaffle::selectWinner` function could revert many times, and make it very difficult to reset the lottery, preventing a new one from starting. 

Also, true winners would not be able to get paid out, and someone else would win their money!

**Proof of Concept:** 
1. 10 smart contract wallets enter the lottery without a fallback or receive function.
2. The lottery ends
3. The `selectWinner` function wouldn't work, even though the lottery is over!

**Recommended Mitigation:** There are a few options to mitigate this issue.

1. Do not allow smart contract wallet entrants (not recommended)
2. Create a mapping of addresses -> payout so winners can pull their funds out themselves, putting the owness on the winner to claim their prize. (Recommended)

### [L-1] `PuppyRaffle.sol::getActivePlayerIndex()` returns 0 if player is inactive leading to misintepretation.

**Description:** 

`PuppyRaffle.sol::getActivePlayerIndex()` returns 0 if an address is not an active player.

**Impact:**

This can be misinterpreted as someone who isn't active may think they are index 0 or the first player who entered the raffle think they did not 
enter the raffle.

In the case of the latter, the player may try to enter again but `PuppyRaffle.sol::enterRaffle()` will revert as he is a duplicate player, therefore, 
the player will waste gas.

**Recommended Mitigation:**

`PuppyRaffle.sol::_isActivePlayer()` is an unused internal function with the recommended mitigation but implemented incorrectly.
> **NOTE:** Modifying original function is recommended - leaving original function as internal makes it redundent code which will also increase
        gas cost for contract deployment.

<details>
<summary> modify <code>PuppyRaffle.sol::_isActivePlayer()</code> to be a public view function </summary>

```diff
+   function isActivePlayer(address playerAddress) public view returns(bool){
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }
```

</details>

### [G-1] Use of storage variables for persistant variables

**Description:**
The following varaibles are all marked as storage when they are unchanged after first implementation:
a. `PuppyRaffle.sol::raffleDuration`
b. `PuppyRaffle.sol::commonImageUri`
c. `PuppyRaffle.sol::rareImageUri`
d. `PuppyRaffle.sol::legendaryImageUri` 

More gas is required when executing functions that read these variables.

**Impact:** 

**Recommended Mitigation:** 

Store a. as an immutable variable and c->d as constant.

### [G-2] For loops reading from storage for each iteration in `PuppyRaffle.sol::enterRaffle()`

**Description:** 

The duplicate player checker reads `PuppyRaffle.sol::players[]` for each iteration of the loop. Storage reads are more
gas expensive and for-loops are (O)^n computationally.

**Recommended Mitigation:**

<details> 
<summary> Cache the players length in memory</summary> 

```diff
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
        }

        // Check for duplicates
+       uint256 _playersArrayLength = players.length;
+       for (uint256 i = 0; i < _playersArrayLength - 1; i++) {
+           for (uint256 j = i + 1; j < _playersArrayLength; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
        emit RaffleEnter(newPlayers);
    }
```
</details>

> **NOTE:** This is under the assumption [H-DoS] mitigations were not implemented or a similar solution with for loops were still used - 
in which case, consider caching storage values if required.

### [I-1] Use of floating pragma can lead to unexpected bahaviour
**Description:**
Using a wide range of solidity can lead to unexpected behaviour.   

**Recommended Mitigation:**
Consider using a specified version of solidity and avoid `^`

### [I-2] Use an older version of solidity is not recommended
**Description:** 
Industry practice to use latest version of solidity or >=0.8.18. 

**Recommended Mitigation:** 
Consider using the latest version of solidity.

### [I-3] Missing check for `address(0)` when assigning values to address state variables.

**Description:** 

Missing `address(0)` check for setting `PuppyRaffle.sol::feeAddress` in first implementation through constructor and also when `PuppyRaffle.sol::changeFeeAddress` is called. 
In the first instance, if no feeAddress is provided during contract creation, address defualts to `adderess(0)`.

**Impact:**
Low

**Recommended Mitigation:**

<details>
<summary> 1. Set a check in the constructor as such: </summary>

```diff
    constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration) ERC721("Puppy Raffle", "PR") {
+       if (_feeAddress == address(0)){
+           revert();
        }
        ... // Rest of code
```
</details>

<details>
<summary> 2. Set a check in <code>PuppyRaffle.sol::changeFeeAddress</code> </summary>

```diff
    function changeFeeAddress(address newFeeAddress) external onlyOwner {
+       if (newFeeAddress == address(0)){
+           revert();
        }
        
        feeAddress = newFeeAddress;
        emit FeeAddressChanged(newFeeAddress);
    }
```
</details>

### [I-4] Multiple users not possible.

**Description:** 

As per the project documentation:

> "A list of addresses that enter. You can use this to enter yourself multiple times, or yourself and a group of your friends."

Multiple users is not actually possible due to the duplicate players search.

**Recommended Mitigation:**

If the project intended to allow multiple entries, the duplicate players check in `PuppyRaffle.sol::enterRaffle()` should be removed.

Removing this has several benefits:

1. Removes the duplicate players check which was shown in [H-Dos] to be a High security vulnerability.
2. Intended funtionality implemented.
3. Not allowing duplicate addresses doesn't necessarily remove duplicate players; players can enter through
   other owned address/es. 

### [I-5] `PuppyRaffle.sol::selectWinner()` does not follow CEI.

**Description:** 

Best practice is to always follow CEI, even if reentrency doesn't seem plausible.

**Recommended Mitigation:** 

<details>
<summary>Modification to <code>PuppyRaffle.sol::selectWinner()</code></summary>

```diff
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 totalAmountCollected = players.length * entranceFee;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
        totalFees = totalFees + uint64(fee);

        uint256 tokenId = totalSupply();

        // We use a different RNG calculate from the winnerIndex to determine rarity
        uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
        if (rarity <= COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity <= COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }

        delete players;
        raffleStartTime = block.timestamp;
        previousWinner = winner;
+       _safeMint(winner, tokenId);
        (bool success,) = winner.call{value: prizePool}("");
        require(success, "PuppyRaffle: Failed to send prize pool to winner");
-       _safeMint(winner, tokenId);
    }

```
</details>

### [I-6] Naming convention 

**Description:** 

Smart contract conventions not followed for variables.

**Recommendation:**

Storage and immutable variables prefixed with s_ & i_, respectfully.

Constant variables are fully capitalised.

### [I-7] Use of magic numbers

**Description:** 

Recommended not to use [magic numbers](https://en.wikipedia.org/wiki/Magic_number_(programming)) in code blocks and clearly state variables beforehand. This is better for readability as well as modularity.

**Recommended Mitigation:** 

In `PuppyRaffle.sol::selectWinner()`, clearly define magic numbers in lines [132](https://github.com/Cyfrin/4-puppy-raffle-audit/blob/15c50ec22382bb1f3106aba660e7c590df18dcac/src/PuppyRaffle.sol#L132) [133](https://github.com/Cyfrin/4-puppy-raffle-audit/blob/15c50ec22382bb1f3106aba660e7c590df18dcac/src/PuppyRaffle.sol#L133) [139](https://github.com/Cyfrin/4-puppy-raffle-audit/blob/15c50ec22382bb1f3106aba660e7c590df18dcac/src/PuppyRaffle.sol#L139)


### Issues I did not find

### [H-4] Malicious winner can forever halt the raffle
<!-- TODO: This is not accurate, but there are some issues. This is likely a low. Users who don't have a fallback can't get their money and the TX will fail. -->

**Description:** Once the winner is chosen, the `selectWinner` function sends the prize to the the corresponding address with an external call to the winner account.

```javascript
(bool success,) = winner.call{value: prizePool}("");
require(success, "PuppyRaffle: Failed to send prize pool to winner");
```

If the `winner` account were a smart contract that did not implement a payable `fallback` or `receive` function, or these functions were included but reverted, the external call above would fail, and execution of the `selectWinner` function would halt. Therefore, the prize would never be distributed and the raffle would never be able to start a new round.

There's another attack vector that can be used to halt the raffle, leveraging the fact that the `selectWinner` function mints an NFT to the winner using the `_safeMint` function. This function, inherited from the `ERC721` contract, attempts to call the `onERC721Received` hook on the receiver if it is a smart contract. Reverting when the contract does not implement such function.

Therefore, an attacker can register a smart contract in the raffle that does not implement the `onERC721Received` hook expected. This will prevent minting the NFT and will revert the call to `selectWinner`.

**Impact:** In either case, because it'd be impossible to distribute the prize and start a new round, the raffle would be halted forever.

**Proof of Concept:** 

<details>
<summary>Proof Of Code</summary>
Place the following test into `PuppyRaffleTest.t.sol`.

```javascript
function testSelectWinnerDoS() public {
    vm.warp(block.timestamp + duration + 1);
    vm.roll(block.number + 1);

    address[] memory players = new address[](4);
    players[0] = address(new AttackerContract());
    players[1] = address(new AttackerContract());
    players[2] = address(new AttackerContract());
    players[3] = address(new AttackerContract());
    puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

    vm.expectRevert();
    puppyRaffle.selectWinner();
}
```

For example, the `AttackerContract` can be this:

```javascript
contract AttackerContract {
    // Implements a `receive` function that always reverts
    receive() external payable {
        revert();
    }
}
```

Or this:

```javascript
contract AttackerContract {
    // Implements a `receive` function to receive prize, but does not implement `onERC721Received` hook to receive the NFT.
    receive() external payable {}
}
```
</details>

**Recommended Mitigation:** Favor pull-payments over push-payments. This means modifying the `selectWinner` function so that the winner account has to claim the prize by calling a function, instead of having the contract automatically send the funds during execution of `selectWinner`.