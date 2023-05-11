// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ContestStatus, WinningSlot, TwoSlotsOption} from "../src/TwoSlotsOption.sol";

contract TwoSlotsOptionTest is Test {
    TwoSlotsOption public twoSlotsOption;
    uint256 mainnetFork;
    uint256 FIRST_MAY_2023 = 1682892000;
    address FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address TOKEN0 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address TOKEN1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint24 UNISWAP_POOL_FEE = 3000;
    address FEE_COLLECTOR = 0x00000000000000000000000000000000DeaDBeef;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        twoSlotsOption =
        new TwoSlotsOption(FACTORY,TOKEN0,TOKEN1,UNISWAP_POOL_FEE, FEE_COLLECTOR, 3, 100, 0.001 ether, 10 ether, 10 minutes);
    }

    function test_getFeeByAmount_FuzzTestCalculations(uint96 _amount) public {
        vm.assume(_amount >= twoSlotsOption.MIN_BET() && _amount <= twoSlotsOption.MAX_BET());
        uint256 expected = _amount * twoSlotsOption.FEE_NUMERATOR() / twoSlotsOption.FEE_DENOMINATOR();
        emit log_named_uint("Amount Expected: ", expected);
        assertEq(twoSlotsOption.getFeeByAmount(_amount), expected);
    }

    function test_CreateContest_CheckIfNewContestCreated() public {
        uint256 expected = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        twoSlotsOption.createContest();
        assertLt(expected, twoSlotsOption.LAST_OPEN_CONTEST_ID());
    }

    function test_CreateContest_CheckContestStatus() public {
        twoSlotsOption.createContest();
        assertTrue(ContestStatus.OPEN == twoSlotsOption.getContestStatus(1));
    }

    function test_CreateContest_CheckWinningSlot() public {
        twoSlotsOption.createContest();
        assertTrue(WinningSlot.UNDEFINED == twoSlotsOption.getContestWinningSlot(1));
    }

    function test_CreateContest_CheckIfNewContestGetStartPrice() public {
        twoSlotsOption.createContest();
        uint256 price = twoSlotsOption.getContestStartingPrice(1);
        emit log_named_uint("Starting Price", price);
        assertGe(price, 0);
    }

    function test_CreateContest_CheckNewContestMaturityPrice() public {
        twoSlotsOption.createContest();
        uint256 price = twoSlotsOption.getContestMaturityPrice(1);
        emit log_named_uint("Maturity Price", price);
        assertEq(price, 0);
    }

    function test_CreateContest_CheckNewContestCloseAtTimeStamp() public {
        vm.warp(FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 expectedCloseAtTimestamp = FIRST_MAY_2023 + 10 minutes;
        emit log_named_uint("Close At", expectedCloseAtTimestamp);
        assertEq(expectedCloseAtTimestamp, twoSlotsOption.getContestCloseAtTimestamp(1));
    }

    function test_CreateContest_CheckNewContestMaturityAtTimeStamp() public {
        vm.warp(FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 expectedMaturityAtTimestamp = FIRST_MAY_2023 + 20 minutes;
        emit log_named_uint("Close At", expectedMaturityAtTimestamp);
        assertEq(expectedMaturityAtTimestamp, twoSlotsOption.getContestMaturityAtTimestamp(1));
    }

    function test_CreateContest_CheckContestCreator() public {
        address alice = makeAddr("alice");
        vm.prank(alice);
        twoSlotsOption.createContest();
        emit log_named_address("Creator", alice);
        assertEq(alice, twoSlotsOption.getContestCreator(1));
    }

    function createContest_CheckContestResolver() public {
        address expectedResolver;
        twoSlotsOption.createContest();
        emit log_named_address("Resolver", twoSlotsOption.getContestResolver(1));
        assertEq(expectedResolver, twoSlotsOption.getContestResolver(1));
    }

    function test_CreateContest_RevertIfContestIsAlreadyOpen() public {
        vm.warp(FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.warp(FIRST_MAY_2023 + 9 minutes);
        vm.expectRevert(abi.encodeWithSelector(TwoSlotsOption.ContestIsAlreadyOpen.selector, lastContestID));
        twoSlotsOption.createContest();
    }

    function test_Bet_RevertIfContestNotInBettingPeriod() public {
        vm.warp(FIRST_MAY_2023);
        twoSlotsOption.createContest();
        vm.warp(FIRST_MAY_2023 + 11 minutes);
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 lastContestCloseAt = twoSlotsOption.getContestCloseAtTimestamp(lastContestID);
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.BettingPeriodExpired.selector, block.timestamp, lastContestCloseAt)
        );
        twoSlotsOption.bet(lastContestID, 100, true);
    }
}
