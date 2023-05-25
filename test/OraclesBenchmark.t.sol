// SPDX-License-Identifier: UNLICENSED
/* solhint-disable var-name-mixedcase */
/* solhint-disable func-name-mixedcase */
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {UniswapV3TWAP} from "../src/UniswapV3TWAP.sol";
import {ChainlinkPriceConsumerV3} from "../src/ChainlinkPriceConsumerV3.sol";

contract OraclesBenchmark is Test {
    uint256 private _arbitrumFork;
    UniswapV3TWAP public uniswapV3TWAP;
    address private _FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // address of UNISWAP V3 FACTORY on Arbitrum network.
    address private _TOKEN0 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum network
    address private _TOKEN1 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum network
    uint24 private _UNISWAP_POOL_FEE = 3000;
    ChainlinkPriceConsumerV3 public chainlinkPriceConsumerV3;
    address private _PRICE_FEED_ADDRESS = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // Chainlink address of ETH/USD PRICE FEED on Arbitrum network.

    function setUp() public {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        _arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(_arbitrumFork);
        uniswapV3TWAP = new UniswapV3TWAP(_FACTORY, _TOKEN0,_TOKEN1,_UNISWAP_POOL_FEE);
        chainlinkPriceConsumerV3 = new ChainlinkPriceConsumerV3(_PRICE_FEED_ADDRESS);
    }

    function test_CHAINLINK_getLatestPrice() public {
        int256 price = chainlinkPriceConsumerV3.getLatestPrice();
        emit log_named_int("CHAINLINK ETH/USD LATEST PRICE", price);
        assertGe(price, 0);
    }

    function test_UNUSWAP_EstimateAmountOut1SecondsAgo() public {
        uint256 price = uniswapV3TWAP.estimateAmountOut(_TOKEN1, 10 ** 18, 1);
        emit log_named_uint("TWAP Price 1 Seconds Ago", price);
        assertGe(price, 0);
    }

    function test_UNUSWAP_EstimateAmountOut6SecondsAgo() public {
        uint256 price = uniswapV3TWAP.estimateAmountOut(_TOKEN1, 10 ** 18, 6);
        emit log_named_uint("TWAP Price 6 Seconds Ago", price);
        assertGe(price, 0);
    }

    function test_UNUSWAP_EstimateAmountOut60SecondsAgo() public {
        uint256 price = uniswapV3TWAP.estimateAmountOut(_TOKEN1, 10 ** 18, 60);
        emit log_named_uint("TWAP Price 60 Seconds Ago", price);
        assertGe(price, 0);
    }

    function test_UNUSWAP_EstimateAmountOut600SecondsAgo() public {
        uint256 price = uniswapV3TWAP.estimateAmountOut(_TOKEN1, 10 ** 18, 600);
        emit log_named_uint("TWAP Price 600 Seconds Ago", price);
        assertGe(price, 0);
    }

    function test_UNUSWAP_EstimateAmountOut6000SecondsAgo() public {
        uint256 price = uniswapV3TWAP.estimateAmountOut(_TOKEN1, 10 ** 18, 6000);
        emit log_named_uint("TWAP Price 6000 Seconds Ago", price);
        assertGe(price, 0);
    }

    function test_UNUSWAP_EstimateAmountOut60000SecondsAgo() public {
        uint256 price = uniswapV3TWAP.estimateAmountOut(_TOKEN1, 10 ** 18, 60000);
        emit log_named_uint("TWAP Price 60000 Seconds Ago", price);
        assertGe(price, 0);
    }

    //TODO: test if differents price with différents seconds in function estimateAmountOut.
}
