// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ContestStatus, WinningSlot, TwoSlotsOption} from "../src/TwoSlotsOption.sol";

contract TwoSlotsOptionTest is Test {
    TwoSlotsOption public twoSlotsOption;
    uint256 arbitrumFork;
    uint256 FIRST_MAY_2023 = 1682892000;
    address FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // address of UNISWAP V3 FACTORY on Arbitrum network.
    address TOKEN0 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum network
    address TOKEN1 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum network
    uint256 public constant FIVE_USDC = 5e6; // 5 dollars in USDC  exponential notation of 6 decimals
    uint256 public constant TEN_THOUSAND_USDC = 1e10; // 10000 dollars in USDC  exponential notation of 6 decimals
    uint24 UNISWAP_POOL_FEE = 3000;
    address FEE_COLLECTOR = 0x00000000000000000000000000000000DeaDBeef;

    function setUp() public {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(arbitrumFork);
        twoSlotsOption =
        new TwoSlotsOption(FACTORY,TOKEN0,TOKEN1,UNISWAP_POOL_FEE, FEE_COLLECTOR, 3, 100, FIVE_USDC, TEN_THOUSAND_USDC, 10 minutes);
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

    function test_Bet_RevertIfContestNotInOpenStatus() public {
        vm.expectRevert(TwoSlotsOption.ContestNotOpen.selector);
        twoSlotsOption.bet(3, FIVE_USDC, true);
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
        twoSlotsOption.bet(lastContestID, FIVE_USDC, true);
    }

    function test_Bet_FuzzRevertIfAmountBetIsLessThanOfMinBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, 0, 4_999_999);
        _amountToBet = bound(_amountToBet, 10_000_000_001, 1e18);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.expectRevert(
            abi.encodeWithSelector(
                TwoSlotsOption.BetAmountOutOfRange.selector,
                _amountToBet,
                twoSlotsOption.MIN_BET(),
                twoSlotsOption.MAX_BET()
            )
        );
        twoSlotsOption.bet(lastContestID, _amountToBet, true);
    }

    function test_Bet_FuzzRevertIfAmountBetIsMoreThanOfMaxBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, 10_000_000_001, 1e18);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.expectRevert(
            abi.encodeWithSelector(
                TwoSlotsOption.BetAmountOutOfRange.selector,
                _amountToBet,
                twoSlotsOption.MIN_BET(),
                twoSlotsOption.MAX_BET()
            )
        );
        twoSlotsOption.bet(lastContestID, _amountToBet, true);
    }
}
