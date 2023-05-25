// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
/* solhint-disable var-name-mixedcase */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SlotsOptionHelper} from "../src/Libraries/SlotsOptionHelper.sol";
import {TwoSlotsOption} from "../src/TwoSlotsOption.sol";
import {MockTwoSlotsOption} from "../src/Mocks/MockTwoSlotsOption.sol";

contract TwoSlotsOptionTestCloseContest is Test {
    using SafeERC20 for IERC20;

    TwoSlotsOption public twoSlotsOption;
    MockTwoSlotsOption public MOCK_TwoSlotsOption;
    uint256 _arbitrumFork;
    uint256 _FIRST_MAY_2023 = 1682892000;
    address _FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // address of UNISWAP V3 _FACTORY on Arbitrum network.
    address _TOKEN0 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum network
    address _TOKEN1 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum network
    uint256 public constant FIVE_USDC = 5 * 1e6; // 5 dollars in USDC  exponential notation of 6 decimals to assign MIN BET
    uint256 public constant TEN_THOUSAND_USDC = 10_000 * 1e6; // 10000 dollars in USDC  exponential notation of 6 decimals
    uint256 public constant ONE_MILION_USDC = 1_000_000 * 1e6; // 1M dollars in USDC  exponential notation of 6 decimals, to assign MAX BET
    uint256 public constant HUNDRED_MILION_USDC = 100_000_000 * 1e6; // 100M dollars in USDC exponential notation of 6 decimals, to assign MAX BET
    uint24 _UNISWAP_POOL_FEE = 3000;
    uint8 public SECONDS_FOR_ORACLE_TWAP = 6;
    uint8 public FEE_COLLECTOR_NUMERATOR = 3; // numerator to calculate fees
    uint8 public FEE_CREATOR_NUMERATOR = 2; // numerator to calculate fees
    uint8 public FEE_RESOLVER_NUMERATOR = 8; // numerator to calculate fees
    uint8 public FEE_DENOMINATOR = 100; // denominator to calculate fees
    uint256 public EPOCH = 10 minutes; // duration of an epoch expressed in seconds
    address _FEE_COLLECTOR = 0x00000000000000000000000000000000DeaDBeef;
    address public wojak = makeAddr("wojak");
    address public alice = makeAddr("alice");
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

    function test__RevertIf_ContestNotOpen() public {
        assertTrue(twoSlotsOption.getContestStatus(10) == SlotsOptionHelper.ContestStatus.UNDEFINED);
        vm.expectRevert(TwoSlotsOption.ContestNotOpen.selector);
        twoSlotsOption.closeContest(10);
    }

    function test_RevertIf_ContestNotMature() public {
        twoSlotsOption.createContest();
        vm.warp(_FIRST_MAY_2023 + 12 minutes);
        uint256 maturityAt = twoSlotsOption.getContestMaturityAtTimestamp(1);
        vm.expectRevert(abi.encodeWithSelector(TwoSlotsOption.ContestNotMature.selector, block.timestamp, maturityAt));
        twoSlotsOption.closeContest(1);
    }

    function test_CheckIfContestStatusRefundableWhenEqualsPrice() public {
        twoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(1, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(1, FIVE_USDC, TwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(1);
        assertTrue(twoSlotsOption.getContestStatus(1) == SlotsOptionHelper.ContestStatus.REFUNDABLE);
    }

    function testMock_CheckIfContestStatusRefundableWhenOnlyOneSlotWithBet() public {
        MOCK_TwoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, true);
        assertTrue(MOCK_TwoSlotsOption.getContestStatus(1) == SlotsOptionHelper.ContestStatus.REFUNDABLE);
    }

    function testMock_ContestStatusChangeIfResolved() public {
        MOCK_TwoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, true);
        assertTrue(MOCK_TwoSlotsOption.getContestStatus(1) == SlotsOptionHelper.ContestStatus.RESOLVED);
    }

    function testMock_CheckIfResolverWhenResolved() public {
        MOCK_TwoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, true);
        assertEq(MOCK_TwoSlotsOption.getContestResolver(1), alice);
    }

    function testMock_CheckWinningSlotWhenResolvedMore() public {
        MOCK_TwoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        assertTrue(MOCK_TwoSlotsOption.getContestWinningSlot(1) == MockTwoSlotsOption.WinningSlot.UNDEFINED);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, true);
        assertTrue(MOCK_TwoSlotsOption.getContestWinningSlot(1) == MockTwoSlotsOption.WinningSlot.MORE);
    }

    function testMock_CheckWinningSlotWhenResolvedLess() public {
        MOCK_TwoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        assertTrue(MOCK_TwoSlotsOption.getContestWinningSlot(1) == MockTwoSlotsOption.WinningSlot.UNDEFINED);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, false);
        assertTrue(MOCK_TwoSlotsOption.getContestWinningSlot(1) == MockTwoSlotsOption.WinningSlot.LESS);
    }

    function testMock_CheckPayoutsWhenResolved() public {
        MOCK_TwoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        MOCK_TwoSlotsOption.bet(1, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, false);
        assertGt(MOCK_TwoSlotsOption.getContestPayout(1, MockTwoSlotsOption.SlotType.LESS), 0);
        assertGt(MOCK_TwoSlotsOption.getContestPayout(1, MockTwoSlotsOption.SlotType.MORE), 0);
    }

    function testMockFuzz_CheckFeeDistributedToCreator(uint256 _amountBetInLess, uint256 _amountBetInMore) public {
        _amountBetInLess = bound(_amountBetInLess, FIVE_USDC, HUNDRED_MILION_USDC);
        _amountBetInMore = bound(_amountBetInMore, FIVE_USDC, HUNDRED_MILION_USDC);
        deal(_TOKEN0, wojak, _amountBetInLess);
        deal(_TOKEN0, alice, _amountBetInMore);
        vm.startPrank(bob);
        MOCK_TwoSlotsOption.createContest();
        vm.stopPrank();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountBetInLess);
        MOCK_TwoSlotsOption.bet(1, _amountBetInLess, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountBetInMore);
        MOCK_TwoSlotsOption.bet(1, _amountBetInMore, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), 0);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, false);
        assertLe(IERC20(_TOKEN0).balanceOf(bob), MOCK_TwoSlotsOption.MAX_FEE_CREATOR());
    }

    function testMockFuzz_CheckFeeDistributedToResolver(uint256 _amountBetInLess, uint256 _amountBetInMore) public {
        _amountBetInLess = bound(_amountBetInLess, FIVE_USDC, HUNDRED_MILION_USDC);
        _amountBetInMore = bound(_amountBetInMore, FIVE_USDC, HUNDRED_MILION_USDC);
        deal(_TOKEN0, wojak, _amountBetInLess);
        deal(_TOKEN0, alice, _amountBetInMore);
        MOCK_TwoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountBetInLess);
        MOCK_TwoSlotsOption.bet(1, _amountBetInLess, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountBetInMore);
        MOCK_TwoSlotsOption.bet(1, _amountBetInMore, MockTwoSlotsOption.SlotType.MORE);
        vm.stopPrank();
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), 0);
        vm.startPrank(bob);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, false);
        assertLe(IERC20(_TOKEN0).balanceOf(bob), MOCK_TwoSlotsOption.MAX_FEE_RESOLVER());
    }

    function testMockFuzz_CheckFeeDistributedToCollector(uint256 _amountBetInLess, uint256 _amountBetInMore) public {
        _amountBetInLess = bound(_amountBetInLess, FIVE_USDC, HUNDRED_MILION_USDC);
        _amountBetInMore = bound(_amountBetInMore, FIVE_USDC, HUNDRED_MILION_USDC);
        deal(_TOKEN0, wojak, _amountBetInLess);
        deal(_TOKEN0, alice, _amountBetInMore);
        MOCK_TwoSlotsOption.createContest();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountBetInLess);
        MOCK_TwoSlotsOption.bet(1, _amountBetInLess, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountBetInMore);
        MOCK_TwoSlotsOption.bet(1, _amountBetInMore, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        assertEq(IERC20(_TOKEN0).balanceOf(bob), 0);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, false);
        uint256 totalFees =
            SlotsOptionHelper.getFee(_amountBetInLess + _amountBetInMore, FEE_COLLECTOR_NUMERATOR, FEE_DENOMINATOR);
        uint256 creatorFees = SlotsOptionHelper.getFee(totalFees, FEE_CREATOR_NUMERATOR, FEE_DENOMINATOR);
        uint256 resolverFees = SlotsOptionHelper.getFee(totalFees, FEE_RESOLVER_NUMERATOR, FEE_DENOMINATOR);
        assertGt(IERC20(_TOKEN0).balanceOf(_FEE_COLLECTOR), creatorFees + resolverFees);
        assertLt(IERC20(_TOKEN0).balanceOf(_FEE_COLLECTOR), totalFees);
    }
}
