// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/UniswapV3TWAP.sol";

contract UniswapV3TWAPTest is Test {
    UniswapV3TWAP public uniswapV3TWAP;
    address FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // address of UNISWAP V3 FACTORY on Arbitrum network.
    address TOKEN0 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum network
    address TOKEN1 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum network
    uint24 UNISWAP_POOL_FEE = 3000;
    uint256 arbitrumFork;

    function setUp() public {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(arbitrumFork);
    }

    function testEstimateAmountOut() public {
        uniswapV3TWAP = new UniswapV3TWAP(FACTORY, TOKEN0,TOKEN1,UNISWAP_POOL_FEE);
        uint256 price = uniswapV3TWAP.estimateAmountOut(TOKEN1, 10 ** 18, 4);
        emit log_named_uint("price : ", price);
        assertGe(price, 0);
    }
}
