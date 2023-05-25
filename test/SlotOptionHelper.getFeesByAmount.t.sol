// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
/* solhint-disable var-name-mixedcase */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SlotsOptionHelper} from "../src/Libraries/SlotsOptionHelper.sol";

contract SlotOptionHelperTestGetFeesByAmount is Test {
    using Strings for uint256;

    uint8 public SECONDS_FOR_ORACLE_TWAP = 6;
    uint8 public FEE_COLLECTOR_NUMERATOR = 3; // numerator to calculate fees
    uint8 public FEE_CREATOR_NUMERATOR = 2; // numerator to calculate fees
    uint8 public FEE_RESOLVER_NUMERATOR = 8; // numerator to calculate fees
    uint8 public FEE_DENOMINATOR = 100; // denominator to calculate fees
    uint256 public constant HUNDRED_MILION_USDC = 100_000_000 * 1e6; // 100M dollars in USDC exponential notation of 6 decimals, to assign MAX BET
    uint256 public MAX_FEE_CREATOR = 5 * 1e6;
    uint256 public MAX_FEE_RESOLVER = 50 * 1e6;
    uint256 public MIN_BET = 5 * 1e6;

    function testFuzz_GetFeesByAmount_MoreThanZero(uint256 _amount) public {
        _amount = bound(_amount, MIN_BET, HUNDRED_MILION_USDC);
        SlotsOptionHelper.Fees memory fees = SlotsOptionHelper.getFeesByAmount(
            _amount,
            FEE_COLLECTOR_NUMERATOR,
            FEE_CREATOR_NUMERATOR,
            FEE_RESOLVER_NUMERATOR,
            FEE_DENOMINATOR,
            MAX_FEE_CREATOR,
            MAX_FEE_RESOLVER
        );
        assertGt(fees.collector + fees.creator + fees.resolver, 0);
    }

    function testFuzz_GetFeesByAmount_TotalEqualAllEntites(uint256 _amount) public {
        _amount = bound(_amount, MIN_BET, HUNDRED_MILION_USDC);
        SlotsOptionHelper.Fees memory fees = SlotsOptionHelper.getFeesByAmount(
            _amount,
            FEE_COLLECTOR_NUMERATOR,
            FEE_CREATOR_NUMERATOR,
            FEE_RESOLVER_NUMERATOR,
            FEE_DENOMINATOR,
            MAX_FEE_CREATOR,
            MAX_FEE_RESOLVER
        );
        assertEq(
            SlotsOptionHelper.getFee(_amount, FEE_COLLECTOR_NUMERATOR, FEE_DENOMINATOR),
            fees.collector + fees.creator + fees.resolver
        );
    }

    function test_GetFeesByAmount_CheckCreatorResolverLimitationsFees(uint256 _amount) public {
        _amount = bound(_amount, MIN_BET, HUNDRED_MILION_USDC);
        SlotsOptionHelper.Fees memory fees = SlotsOptionHelper.getFeesByAmount(
            _amount,
            FEE_COLLECTOR_NUMERATOR,
            FEE_CREATOR_NUMERATOR,
            FEE_RESOLVER_NUMERATOR,
            FEE_DENOMINATOR,
            MAX_FEE_CREATOR,
            MAX_FEE_RESOLVER
        );
        assertLt(fees.creator, fees.resolver);
        assertLe(fees.creator, MAX_FEE_CREATOR);
        assertLe(fees.resolver, MAX_FEE_RESOLVER);
    }
}
