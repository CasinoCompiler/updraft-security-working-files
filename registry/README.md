# Fuzzing exercise 

This is a simple fuzzing [exercise](https://gist.github.com/tinchoabbate/67b195b95fe77a5b9e3c6cc4bf80b3f7) created by Tinchoabbate to improve my ability for stateful invariant testing.

## Description

This is a short and simple exercise to start sharpening your smart contract fuzzing skills with Foundry.

The scenario is simple. There's a registry contract that allows callers to register by paying a fixed fee in ETH. If the caller sends too little ETH, execution should revert. If the caller sends too much ETH, the contract should give back the change.

Things look good according to the unit test we coded in the Registry.t.sol contract.

Your goal is to code at least one fuzz test for the Registry contract. By following the brief specification above, the test must be able to detect a bug in the register function.