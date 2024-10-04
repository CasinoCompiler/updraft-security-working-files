### [H-1] Variables stored on-chain are not hidden; anyone can find the password.  

**Description:**

One use-case of the smart contract `PasswordStore.sol` is to retrieve `PasswordStore.sol::s_password` and only the user is able to retrieve this password. This function (`PasswordStore.sol::getPassword()`) is implemented correctly,
but the purpose of the function as stated by the documentation is to _hide_ the password.

Solidity keywords of public, private, external, internal only specify an allowed contract-to-contract interaction.

_Variables stored on chain are visible to everyone at all times._ 

Therefore, the password is obtainable by anyone the moment the contract is deployed.

Proof of concept is stated below.

**Impact:** Anyone can read the private password, severly breaking the functionality of the contract.

**Proof of Concept:**

1. Create a locally running chain.
```bash
make anvil
```

2. Deploy the contracts.
```bash
make deploy
```

3. Run the storage tool
```bash
cast storage <Passwordstore_contract_address>
```
4. Copy the hex value associated with s_password.


5. Use command to convert hex value to string
```bash
cast parse-bytes32-string <copied_hex_value>
```

6. Password is now visible.


**Recommended Mitigation:** 

sensative data should not be stored on a blockchain. the use of a blockchain is to verify ownership, and your "password" is your private-key.

use an offline password storage system. This protocol / contract should not exist.

If you wanted to create some kind of 2-stage encryption password with the decryption key offline, that is a different protocol altogether;
additionally, you would have to ensure the decryption key is robust as someone crazy would eventually be able to decrypt your password.


### [H-2] `PasswordStore.sol::setPassword()` lacks correct access control, so anyone can set the password.

**Description:** 

Another use case of the protocol is to set a password. Each time `PasswordStore.sol::setPassword()` is called, the password can be changed. 
The purpose is so that only the `PasswordStore.sol::s_owner` is able to set the password.

no checks in place for intended purpose.

Proof of concept is stated below.

**Impact:** 

Anyone can change the password.

**Proof of Concept:**

Add the following test to `PasswordStore.t.sol`:

<details>
<summary> Code </summary>

```javascript

    function test_AnyoneCanChangePassword(address randomAddress) public {
        // Pick arbitrary password
        string memory changedPassword = "changed password";

        // Simulate non-owner calling setPassword()
        vm.assume(randomAddress != owner);
        vm.startPrank(randomAddress);
        passwordStore.setPassword(changedPassword);
        vm.stopPrank();

        // Retrieve password by calling getPassword with owner
        vm.startPrank(owner);
        string memory actualPassword = passwordStore.getPassword();
        vm.stopPrank();

        // Assert password is equal to value alice set.
        assertEq(actualPassword, changedPassword);
    }
```
</details>


**Recommended Mitigation:** 

Add access control check at the beginning of `PasswordStore.sol::setPassword()`:

```javascript
if (msg.sender != s_owner) {
    revert PasswordStore__NotOwner();
}
```

### [I-1] Documentation states a non-existent @param

**Description:** 

```javascript

    /*
     * @notice This allows only the owner to retrieve the password.
@>   * @param newPassword The new password to set.
     */
    function getPassword() external view returns (string memory) ...
```

The `PasswordStore.sol::getPassword()` function signature is `getPassword()` while the natspec says it should be `getPassword(string)`

**Impact:** 

incorrect natspec

**Recommended Mitigation:** 

Remove incorrect natspec line

```diff
    /*
     * @notice This allows only the owner to retrieve the password.
-   * @param newPassword The new password to set.
     */
```