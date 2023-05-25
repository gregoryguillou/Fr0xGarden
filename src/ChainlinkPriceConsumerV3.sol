// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceConsumerV3 {
    AggregatorV3Interface internal _priceFeed;

    /**
     * Network: Arbitrum
     * Aggregator: ETH/USD
     * Address: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
     */
    constructor(address _priceFeedAddress) {
        _priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    /**
     * Returns the latest price.
     */
    function getLatestPrice() public view returns (int256) {
        // prettier-ignore
        (
            /* uint80 roundID */
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = _priceFeed.latestRoundData();
        return price;
    }
}
