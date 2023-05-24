// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
/* solhint-disable var-name-mixedcase */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SlotsOptionHelper} from "../src/Libraries/SlotsOptionHelper.sol";
import {TwoSlotsOption} from "../src/TwoSlotsOption.sol";
import {MockTwoSlotsOption} from "../src/Mocks/MockTwoSlotsOption.sol";

contract TwoSlotsOptionTest is Test {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    TwoSlotsOption public twoSlotsOption;
    MockTwoSlotsOption public MOCK_TwoSlotsOption;
    uint256 _arbitrumFork;
    uint256 _FIRST_MAY_2023 = 1682892000;
    address _FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // address of UNISWAP V3 _FACTORY on Arbitrum network.
    address _TOKEN0 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum network
    address _TOKEN1 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum network
    uint256 public constant FIVE_USDC = 5 * 1e6; // 5 dollars in USDC  exponential notation of 6 decimals to assign MIN BET
    uint256 public constant ONE_MILION_USDC = 1_000_000 * 1e6; // 1M dollars in USDC  exponential notation of 6 decimals, to assign MAX BET
    uint256 public constant TEN_THOUSAND_USDC = 10_000 * 1e6; // 10000 dollars in USDC  exponential notation of 6 decimals
    uint256 public constant HUNDRED_MILION_USDC = 100_000_000 * 1e6; // 100M dollars in USDC exponential notation of 6 decimals, to assign MAX BET
    uint24 _UNISWAP_POOL_FEE = 3000;
    uint8 public SECONDS_FOR_ORACLE_TWAP = 6;
    uint8 public FEE_COLLECTOR_NUMERATOR = 3; // numerator to calculate fees
    uint8 public FEE_CREATOR_NUMERATOR = 2; // numerator to calculate fees
    uint8 public FEE_RESOLVER_NUMERATOR = 8; // numerator to calculate fees
    uint8 public FEE_DENOMINATOR = 100; // denominator to calculate fees
    uint256 public EPOCH = 10 minutes; // duration of an epoch expressed in seconds
    address _FEE_COLLECTOR = 0x00000000000000000000000000000000DeaDBeef;
    address public alice = makeAddr("alice");
    address public wojak = makeAddr("wojak");
    address public bob = makeAddr("bob");
    address public milady = makeAddr("milady");

    function setUp() public {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        _arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(_arbitrumFork);
        twoSlotsOption =
        new TwoSlotsOption(_FEE_COLLECTOR,_FACTORY,_TOKEN0,_TOKEN1,_UNISWAP_POOL_FEE, SECONDS_FOR_ORACLE_TWAP,FEE_DENOMINATOR, FEE_COLLECTOR_NUMERATOR,FEE_CREATOR_NUMERATOR ,FEE_RESOLVER_NUMERATOR, FIVE_USDC, EPOCH);
        MOCK_TwoSlotsOption =
        new MockTwoSlotsOption(_FEE_COLLECTOR,_FACTORY,_TOKEN0,_TOKEN1,_UNISWAP_POOL_FEE, SECONDS_FOR_ORACLE_TWAP,FEE_DENOMINATOR, FEE_COLLECTOR_NUMERATOR,FEE_CREATOR_NUMERATOR ,FEE_RESOLVER_NUMERATOR, FIVE_USDC, EPOCH);
        vm.warp(_FIRST_MAY_2023);
        deal(_TOKEN0, wojak, ONE_MILION_USDC);
        deal(_TOKEN0, alice, ONE_MILION_USDC);
    }

    function test_RevertIf_ContestStatusUNDEFINED() public {
        vm.expectRevert(TwoSlotsOption.ContestNotOpen.selector);
        twoSlotsOption.bet(3, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
    }

    function test_RevertIf_ContestStatusREFUNDABLE() public {
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(lastContestID);
        assertEq(
            uint8(twoSlotsOption.getContestStatus(lastContestID)), uint8(SlotsOptionHelper.ContestStatus.REFUNDABLE)
        );
        vm.expectRevert(TwoSlotsOption.ContestNotOpen.selector);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
    }

    function testMock_RevertIf_ContestStatusRESOLVED() public {
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(lastContestID, FIVE_USDC, false);
        assertEq(
            uint8(MOCK_TwoSlotsOption.getContestStatus(lastContestID)), uint8(SlotsOptionHelper.ContestStatus.RESOLVED)
        );
        vm.expectRevert(MockTwoSlotsOption.ContestNotOpen.selector);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
    }

    function test_RevertIf_ContestNotInBettingPeriod() public {
        twoSlotsOption.createContest();
        vm.warp(_FIRST_MAY_2023 + 11 minutes);
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 lastContestCloseAt = twoSlotsOption.getContestCloseAtTimestamp(lastContestID);
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.BettingPeriodExpired.selector, block.timestamp, lastContestCloseAt)
        );
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
    }

    function testFuzz_RevertIf_AmountBetIsLessThanOfMinBet(uint256 _amountToBet) public {
        vm.assume(_amountToBet < twoSlotsOption.MIN_BET());
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.expectRevert(
            abi.encodeWithSelector(
                TwoSlotsOption.InsufficientBetAmount.selector, _amountToBet, twoSlotsOption.MIN_BET()
            )
        );
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                TwoSlotsOption.InsufficientBetAmount.selector, _amountToBet, twoSlotsOption.MIN_BET()
            )
        );
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.MORE);
    }

    function testFuzz_RevertIf_UserBalanceLessThanAmountToBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC - 1);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        deal(_TOKEN0, bob, _amountToBet);
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.InsufficientBalance.selector, _amountToBet, ONE_MILION_USDC)
        );
        twoSlotsOption.bet(lastContestID, ONE_MILION_USDC, TwoSlotsOption.SlotType.LESS);
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.InsufficientBalance.selector, _amountToBet, ONE_MILION_USDC)
        );
        twoSlotsOption.bet(lastContestID, ONE_MILION_USDC, TwoSlotsOption.SlotType.MORE);
    }

    function testFuzz_RevertIf_UserAllowanceLessThanAmountToBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        deal(_TOKEN0, bob, _amountToBet);
        vm.startPrank(bob);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), FIVE_USDC - 1);
        uint256 contractAllowance = IERC20(_TOKEN0).allowance(bob, address(twoSlotsOption));
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.InsufficientAllowance.selector, contractAllowance, _amountToBet)
        );
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.InsufficientAllowance.selector, contractAllowance, _amountToBet)
        );
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.MORE);
    }

    function testFuzz_Bet_CheckIfUserBetIncreaseTotalAmountInSlot(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC * 2, ONE_MILION_USDC);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountToBet);
        twoSlotsOption.bet(lastContestID, _amountToBet / 2, TwoSlotsOption.SlotType.LESS);
        uint256 expectedAmountInSlotLess =
            twoSlotsOption.getAmountBetInSlot(lastContestID, TwoSlotsOption.SlotType.LESS);
        assertEq(expectedAmountInSlotLess, _amountToBet / 2);
        twoSlotsOption.bet(lastContestID, _amountToBet / 2, TwoSlotsOption.SlotType.MORE);
        uint256 expectedAmountInSlotMore =
            twoSlotsOption.getAmountBetInSlot(lastContestID, TwoSlotsOption.SlotType.MORE);
        assertEq(expectedAmountInSlotMore, _amountToBet / 2);
    }

    function test_CheckIfUserBetChangeOptionStatusToCREATED() public {
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        SlotsOptionHelper.OptionStatus expectedOptionStatus =
            twoSlotsOption.getOptionStatus(lastContestID, TwoSlotsOption.SlotType.LESS, alice);
        assertTrue(SlotsOptionHelper.OptionStatus.CREATED == expectedOptionStatus);
    }

    function test_Bet_CheckIfUserBetIncreaseAmountInOption() public {
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        uint256 expectedAmountInOptionLess =
            twoSlotsOption.getAmountBetInOption(lastContestID, TwoSlotsOption.SlotType.LESS, alice);
        assertEq(expectedAmountInOptionLess, FIVE_USDC * 2);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.MORE);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.MORE);
        uint256 expectedAmountInOptionMore =
            twoSlotsOption.getAmountBetInOption(lastContestID, TwoSlotsOption.SlotType.LESS, alice);
        assertEq(expectedAmountInOptionMore, FIVE_USDC * 2);
    }

    function testFuzz_CheckIfBalancesChangeWithBetOnLess(uint256 _amountBet) public {
        _amountBet = bound(_amountBet, FIVE_USDC, ONE_MILION_USDC);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(bob);
        deal(_TOKEN0, bob, _amountBet);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountBet);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), _amountBet);
        twoSlotsOption.bet(lastContestID, _amountBet, TwoSlotsOption.SlotType.LESS);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), 0);
        assertEq(IERC20(_TOKEN0).balanceOf(address(twoSlotsOption)), _amountBet);
    }

    function testFuzz_CheckIfBalancesChangeWithBetOnMore(uint256 _amountBet) public {
        _amountBet = bound(_amountBet, FIVE_USDC, ONE_MILION_USDC);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(bob);
        deal(_TOKEN0, bob, _amountBet);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountBet);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), _amountBet);
        twoSlotsOption.bet(lastContestID, _amountBet, TwoSlotsOption.SlotType.MORE);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), 0);
        assertEq(IERC20(_TOKEN0).balanceOf(address(twoSlotsOption)), _amountBet);
    }

    function testFuzz_CheckIfBalancesChangeWithBetOnTwoSlots(uint256 _amountBetOnLess, uint256 _amountBetOnMore)
        public
    {
        _amountBetOnLess = bound(_amountBetOnLess, FIVE_USDC, ONE_MILION_USDC);
        _amountBetOnMore = bound(_amountBetOnMore, FIVE_USDC, ONE_MILION_USDC);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(bob);
        deal(_TOKEN0, bob, _amountBetOnLess);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountBetOnLess);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), _amountBetOnLess);
        twoSlotsOption.bet(lastContestID, _amountBetOnLess, TwoSlotsOption.SlotType.LESS);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), 0);
        assertEq(IERC20(_TOKEN0).balanceOf(address(twoSlotsOption)), _amountBetOnLess);
        vm.stopPrank();
        vm.startPrank(milady);
        deal(_TOKEN0, milady, _amountBetOnMore);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountBetOnMore);
        assertEq(IERC20(_TOKEN0).balanceOf(milady), _amountBetOnMore);
        twoSlotsOption.bet(lastContestID, _amountBetOnMore, TwoSlotsOption.SlotType.MORE);
        assertEq(IERC20(_TOKEN0).balanceOf(milady), 0);
        assertEq(IERC20(_TOKEN0).balanceOf(address(twoSlotsOption)), _amountBetOnLess + _amountBetOnMore);
    }
}
