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

contract TwoSlotsOptionTestClaimRefund is Test {
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
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public wojak = makeAddr("wojak");
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
        assertTrue(twoSlotsOption.getContestStatus(10) == SlotsOptionHelper.ContestStatus.UNDEFINED);
        vm.expectRevert(TwoSlotsOption.ContestNotClose.selector);
        twoSlotsOption.claimRefund(10);
    }

    function test_RevertIf_ContestStatusOPEN() public {
        twoSlotsOption.createContest();
        assertTrue(twoSlotsOption.getContestStatus(1) == SlotsOptionHelper.ContestStatus.OPEN);
        vm.expectRevert(TwoSlotsOption.ContestNotClose.selector);
        twoSlotsOption.claimRefund(1);
    }

    function testMock_RevertIf_ContestStatusRESOLVED() public {
        vm.startPrank(alice);
        MOCK_TwoSlotsOption.createContest();
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, ONE_MILION_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.stopPrank();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, ONE_MILION_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, false);
        assertTrue(MOCK_TwoSlotsOption.getContestStatus(1) == SlotsOptionHelper.ContestStatus.RESOLVED);
        vm.expectRevert(MockTwoSlotsOption.ContestNotRefundable.selector);
        MOCK_TwoSlotsOption.claimRefund(1);
    }

    function test_RevertIf_UserNoNeedRefundBecauseNoBets() public {
        twoSlotsOption.createContest();
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(1);
        vm.expectRevert(TwoSlotsOption.UserNoNeedRefund.selector);
        twoSlotsOption.claimRefund(1);
    }

    function test_RevertIf_UsersNoNeedRefundBecauseAlreadyRefunded() public {
        vm.startPrank(alice);
        twoSlotsOption.createContest();
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(1, ONE_MILION_USDC / 2, TwoSlotsOption.SlotType.MORE);
        twoSlotsOption.bet(1, ONE_MILION_USDC / 2, TwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(1, ONE_MILION_USDC, TwoSlotsOption.SlotType.LESS);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(1);
        twoSlotsOption.claimRefund(1);
        vm.expectRevert(TwoSlotsOption.UserNoNeedRefund.selector);
        twoSlotsOption.claimRefund(1);
        vm.stopPrank();
        vm.startPrank(alice);
        twoSlotsOption.claimRefund(1);
        vm.expectRevert(TwoSlotsOption.UserNoNeedRefund.selector);
        twoSlotsOption.claimRefund(1);
    }

    function test_OptionStatusChangeIfOneOptionToRefund() public {
        vm.startPrank(wojak);
        twoSlotsOption.createContest();
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(1, ONE_MILION_USDC, TwoSlotsOption.SlotType.LESS);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(1);
        twoSlotsOption.claimRefund(1);
        SlotsOptionHelper.OptionStatus wojakOptionStatusLess =
            twoSlotsOption.getOptionStatus(1, TwoSlotsOption.SlotType.LESS, wojak);
        assertTrue(wojakOptionStatusLess == SlotsOptionHelper.OptionStatus.REFUNDED);
        SlotsOptionHelper.OptionStatus wojakOptionStatusMore =
            twoSlotsOption.getOptionStatus(1, TwoSlotsOption.SlotType.MORE, wojak);
        assertTrue(wojakOptionStatusMore == SlotsOptionHelper.OptionStatus.UNDEFINED);
    }

    function test_OptionStatusChangeIfTwoOptionsToRefund() public {
        vm.startPrank(alice);
        twoSlotsOption.createContest();
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(1, ONE_MILION_USDC / 2, TwoSlotsOption.SlotType.MORE);
        twoSlotsOption.bet(1, ONE_MILION_USDC / 2, TwoSlotsOption.SlotType.LESS);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(1);
        twoSlotsOption.claimRefund(1);
        SlotsOptionHelper.OptionStatus aliceOptionStatusLess =
            twoSlotsOption.getOptionStatus(1, TwoSlotsOption.SlotType.LESS, alice);
        assertTrue(aliceOptionStatusLess == SlotsOptionHelper.OptionStatus.REFUNDED);
        SlotsOptionHelper.OptionStatus aliceOptionStatusMore =
            twoSlotsOption.getOptionStatus(1, TwoSlotsOption.SlotType.MORE, alice);
        assertTrue(aliceOptionStatusMore == SlotsOptionHelper.OptionStatus.REFUNDED);
    }

    function test_BalancesChangeIfOneOptionToRefund() public {
        vm.startPrank(wojak);
        twoSlotsOption.createContest();
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(1, ONE_MILION_USDC, TwoSlotsOption.SlotType.LESS);
        assertEq(IERC20(_TOKEN0).balanceOf(wojak), 0);
        assertEq(IERC20(_TOKEN0).balanceOf(address(twoSlotsOption)), ONE_MILION_USDC);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(1);
        twoSlotsOption.claimRefund(1);
        assertEq(IERC20(_TOKEN0).balanceOf(wojak), ONE_MILION_USDC);
        assertEq(IERC20(_TOKEN0).balanceOf(address(twoSlotsOption)), 0);
    }

    function test_BalancesChangeIfTwoOptionToRefund() public {
        vm.startPrank(alice);
        twoSlotsOption.createContest();
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(1, ONE_MILION_USDC / 2, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(1, ONE_MILION_USDC / 2, TwoSlotsOption.SlotType.MORE);
        assertEq(IERC20(_TOKEN0).balanceOf(alice), 0);
        assertEq(IERC20(_TOKEN0).balanceOf(address(twoSlotsOption)), ONE_MILION_USDC);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(1);
        twoSlotsOption.claimRefund(1);
        assertEq(IERC20(_TOKEN0).balanceOf(alice), ONE_MILION_USDC);
        assertEq(IERC20(_TOKEN0).balanceOf(address(twoSlotsOption)), 0);
    }

    function testMock_BalancesChangeIfRefundButDifferentsPrices() public {
        vm.startPrank(wojak);
        MOCK_TwoSlotsOption.createContest();
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(1, ONE_MILION_USDC, MockTwoSlotsOption.SlotType.LESS);
        assertEq(IERC20(_TOKEN0).balanceOf(wojak), 0);
        assertEq(IERC20(_TOKEN0).balanceOf(address(MOCK_TwoSlotsOption)), ONE_MILION_USDC);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(1, FIVE_USDC, false);
        MOCK_TwoSlotsOption.claimRefund(1);
        assertEq(IERC20(_TOKEN0).balanceOf(wojak), ONE_MILION_USDC);
        assertEq(IERC20(_TOKEN0).balanceOf(address(MOCK_TwoSlotsOption)), 0);
    }
}
