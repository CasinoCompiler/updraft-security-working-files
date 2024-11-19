using GasBadNftMarketplace as gasBadMarketplace;
using NftMarketplace as nftmarketplace;

methods {
    function _.safeTransferFrom(address, address, uint256) external envfree => DISPATCHER(true);
    function _.onERC721Received(address, address, uint256, bytes) external => ALWAYS(1);
}

ghost mathint listingUpdatesCount {
    init_state axiom listingUpdatesCount == 0;
}
ghost mathint log4count {
    init_state axiom log4count == 0;
}

hook Sstore s_listings[KEY address nftAddress][KEY uint256 listingId].price uint256 price {
    listingUpdatesCount = listingUpdatesCount + 1;
}

hook LOG4(uint offset, uint length, bytes32 t1, bytes32 t2, bytes32 t3, bytes32 t4) {
    log4count = log4count + 1;
}

invariant anytime_mapping_updated_emit_event()
    listingUpdatesCount <= log4count;

rule calling_any_function_should_result_in_the_same_state(){
    method f;
    method f2;

    env e;
    calldataarg args;

   // They start in the same state
    require(gasBadMarketplace.getProceeds(e, seller) == nftmarketplace.getProceeds(e, seller));
    require(gasBadMarketplace.getListing(e, listingAddr, tokenId).price == nftmarketplace.getListing(e, listingAddr, tokenId).price);
    require(gasBadMarketplace.getListing(e, listingAddr, tokenId).seller == nftmarketplace.getListing(e, listingAddr, tokenId).seller);

    // It's the same function on each
    require f.selector == f2.selector;
    gasBadMarketplace.f(e, args);
    nftmarketplace.f2(e, args);

    // They end in the same state
    assert(gasBadMarketplace.getListing(e, listingAddr, tokenId).price == nftmarketplace.getListing(e, listingAddr, tokenId).price);
    assert(gasBadMarketplace.getListing(e, listingAddr, tokenId).seller == nftmarketplace.getListing(e, listingAddr, tokenId).seller);
    assert(gasBadMarketplace.getProceeds(e, seller) == nftmarketplace.getProceeds(e, seller));

}