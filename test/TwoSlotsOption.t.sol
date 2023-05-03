// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/TwoSlotsOption.sol";

contract MutualSlotsTest is Test {
    TwoSlotsOption public twoSlotsOption;

    function setUp() public {
        address FEE_COLLECTOR = 0x00000000000000000000000000000000DeaDBeef;
        twoSlotsOption = new TwoSlotsOption(FEE_COLLECTOR, 3, 100, 0.001 ether, 10 ether, 10 minutes);
    }

    function testGetFeeByAmount(uint96 _amount) public {
        vm.assume(_amount >= twoSlotsOption.MIN_BET() && _amount <= twoSlotsOption.MAX_BET());
        uint256 expected = _amount * twoSlotsOption.FEE_NUMERATOR() / twoSlotsOption.FEE_DENOMINATOR();
        emit log_named_uint("Amount Expected: ", expected);
        assertEq(twoSlotsOption.getFeeByAmount(_amount), expected);
    }
}
