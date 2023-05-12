// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/UniswapV3TWAP.sol";

contract UniswapV3TWAPTest is Test {
    UniswapV3TWAP public uniswapV3TWAP;
    address FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address TOKEN0 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address TOKEN1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint24 UNISWAP_POOL_FEE = 3000;
    uint256 mainnetFork;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    function testEstimateAmountOut() public {
        vm.selectFork(mainnetFork);
        uniswapV3TWAP = new UniswapV3TWAP(FACTORY, TOKEN0,TOKEN1,UNISWAP_POOL_FEE);
        uint256 price = uniswapV3TWAP.estimateAmountOut(TOKEN1, 10 ** 18, 4);
        emit log_named_uint("price : ", price);
        assertGe(price, 0);
    }
}
