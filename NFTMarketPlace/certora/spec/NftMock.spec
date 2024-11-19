methods {
    function totalSupply() external returns uint256 envfree;
    function mint() external;
    function balanceOf(address) external returns(uint256) envfree;
}

rule mintingMintsOneNFT {
    env e;
    address minter;

    require e.msg.value == 0;
    require e.msg.sender == minter;

    mathint balanceBefore = balanceOf(minter);
    currentContract.mint(e);
    
    assert((balanceBefore + 1) == balanceOf(minter));

}

invariant totalSupplyShouldNeverBeNegative()
    totalSupply() >= 0;