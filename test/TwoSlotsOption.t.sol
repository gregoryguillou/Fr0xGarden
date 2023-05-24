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
    }

    function testFuzz_GetFeesByAmount_MoreThanZero(uint256 _amount) public {
        _amount = bound(_amount, twoSlotsOption.MIN_BET(), HUNDRED_MILION_USDC);
        uint256 MAX_FEE_CREATOR = 5 * 1e6;
        uint256 MAX_FEE_RESOLVER = 50 * 1e6;
        SlotsOptionHelper.Fees memory fees = SlotsOptionHelper.getFeesByAmount(
            _amount,
            twoSlotsOption.FEE_COLLECTOR_NUMERATOR(),
            twoSlotsOption.FEE_CREATOR_NUMERATOR(),
            twoSlotsOption.FEE_RESOLVER_NUMERATOR(),
            twoSlotsOption.FEE_DENOMINATOR(),
            MAX_FEE_CREATOR,
            MAX_FEE_RESOLVER
        );
        uint256 totalFees = fees.collector + fees.creator + fees.resolver;

        emit log_named_uint("Amount Expected: ", totalFees);
        assertGt(totalFees, 0);
    }

    function testFuzz_GetFeesByAmount_TotalEqualAllEntites(uint256 _amount) public {
        _amount = bound(_amount, twoSlotsOption.MIN_BET(), HUNDRED_MILION_USDC);
        uint256 MAX_FEE_CREATOR = 5 * 1e6;
        uint256 MAX_FEE_RESOLVER = 50 * 1e6;
        SlotsOptionHelper.Fees memory fees = SlotsOptionHelper.getFeesByAmount(
            _amount,
            twoSlotsOption.FEE_COLLECTOR_NUMERATOR(),
            twoSlotsOption.FEE_CREATOR_NUMERATOR(),
            twoSlotsOption.FEE_RESOLVER_NUMERATOR(),
            twoSlotsOption.FEE_DENOMINATOR(),
            MAX_FEE_CREATOR,
            MAX_FEE_RESOLVER
        );
        uint256 totalFees = SlotsOptionHelper.getFee(
            _amount, twoSlotsOption.FEE_COLLECTOR_NUMERATOR(), twoSlotsOption.FEE_DENOMINATOR()
        );
        emit log_named_uint("Total Fees: ", totalFees);
        uint256 allEntites = fees.collector + fees.creator + fees.resolver;
        emit log_named_uint("All Entites: ", allEntites);
        assertEq(totalFees, allEntites);
    }

    function test_GetFeesByAmount_CheckCreatorResolverLimitationsFees(uint256 _amount) public {
        _amount = bound(_amount, twoSlotsOption.MIN_BET(), HUNDRED_MILION_USDC);
        uint256 MAX_FEE_CREATOR = 5 * 1e6;
        uint256 MAX_FEE_RESOLVER = 50 * 1e6;
        SlotsOptionHelper.Fees memory fees = SlotsOptionHelper.getFeesByAmount(
            _amount,
            twoSlotsOption.FEE_COLLECTOR_NUMERATOR(),
            twoSlotsOption.FEE_CREATOR_NUMERATOR(),
            twoSlotsOption.FEE_RESOLVER_NUMERATOR(),
            twoSlotsOption.FEE_DENOMINATOR(),
            MAX_FEE_CREATOR,
            MAX_FEE_RESOLVER
        );
        uint256 totalFees = fees.collector + fees.creator + fees.resolver;
        emit log_named_uint("Amount Expected: ", totalFees);
        emit log_named_uint("Fees Creator: ", fees.creator);
        emit log_named_uint("Fees Resolver: ", fees.resolver);
        assertLt(fees.creator, fees.resolver);
        assertLe(fees.creator, MAX_FEE_CREATOR);
        assertLe(fees.resolver, MAX_FEE_RESOLVER);
    }

    function test_CreateContest_CheckIfNewContestCreated() public {
        uint256 expected = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        twoSlotsOption.createContest();
        assertLt(expected, twoSlotsOption.LAST_OPEN_CONTEST_ID());
    }

    function test_CreateContest_CheckContestStatus() public {
        twoSlotsOption.createContest();
        assertTrue(SlotsOptionHelper.ContestStatus.OPEN == twoSlotsOption.getContestStatus(1));
    }

    function test_CreateContest_CheckWinningSlot() public {
        twoSlotsOption.createContest();
        assertTrue(TwoSlotsOption.WinningSlot.UNDEFINED == twoSlotsOption.getContestWinningSlot(1));
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
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 expectedCloseAtTimestamp = _FIRST_MAY_2023 + 10 minutes;
        emit log_named_uint("Close At", expectedCloseAtTimestamp);
        assertEq(expectedCloseAtTimestamp, twoSlotsOption.getContestCloseAtTimestamp(1));
    }

    function test_CreateContest_CheckNewContestMaturityAtTimeStamp() public {
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 expectedMaturityAtTimestamp = _FIRST_MAY_2023 + 20 minutes;
        emit log_named_uint("Maturity At", expectedMaturityAtTimestamp);
        assertEq(expectedMaturityAtTimestamp, twoSlotsOption.getContestMaturityAtTimestamp(1));
    }

    function test_CreateContest_CheckContestCreator() public {
        vm.prank(alice);
        twoSlotsOption.createContest();
        emit log_named_address("Creator", alice);
        assertEq(alice, twoSlotsOption.getContestCreator(1));
    }

    function test_CreateContest_RevertIfContestIsAlreadyOpen() public {
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.warp(_FIRST_MAY_2023 + 9 minutes);
        vm.expectRevert(abi.encodeWithSelector(TwoSlotsOption.ContestIsAlreadyOpen.selector, lastContestID));
        twoSlotsOption.createContest();
    }

    function test_Bet_RevertIfContestNotInOpenStatus() public {
        vm.expectRevert(TwoSlotsOption.ContestNotOpen.selector);
        twoSlotsOption.bet(3, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
    }

    function test_Bet_RevertIfContestNotInBettingPeriod() public {
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        vm.warp(_FIRST_MAY_2023 + 11 minutes);
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 lastContestCloseAt = twoSlotsOption.getContestCloseAtTimestamp(lastContestID);
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.BettingPeriodExpired.selector, block.timestamp, lastContestCloseAt)
        );
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
    }

    function testFuzz_Bet_RevertIfAmountBetIsLessThanOfMinBet(uint256 _amountToBet) public {
        vm.assume(_amountToBet < twoSlotsOption.MIN_BET());
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.expectRevert(
            abi.encodeWithSelector(
                TwoSlotsOption.InsufficientBetAmount.selector, _amountToBet, twoSlotsOption.MIN_BET()
            )
        );
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
    }

    function testFuzz_Bet_RevertIfUserBalanceIsLessThanAmountToBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC - 1);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        deal(_TOKEN0, alice, _amountToBet);
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.InsufficientBalance.selector, _amountToBet, ONE_MILION_USDC)
        );
        twoSlotsOption.bet(lastContestID, ONE_MILION_USDC, TwoSlotsOption.SlotType.LESS);
    }

    function testFuzz_Bet_RevertIfUserAllowanceIsLessThanAmountToBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        deal(_TOKEN0, alice, _amountToBet);
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), FIVE_USDC - 1);
        uint256 contractAllowance = IERC20(_TOKEN0).allowance(alice, address(twoSlotsOption));
        emit log_named_uint("Contract Allowance", contractAllowance);
        vm.expectRevert(
            abi.encodeWithSelector(TwoSlotsOption.InsufficientAllowance.selector, contractAllowance, _amountToBet)
        );
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
    }

    function testFuzz_Bet_CheckIfUserBetIncreaseTotalAmountInSlot(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, _amountToBet);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountToBet);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
        uint256 expectedAmountInSlotLess =
            twoSlotsOption.getAmountBetInSlot(lastContestID, TwoSlotsOption.SlotType.LESS);
        emit log_named_uint("Expected Amount In Slot Less", expectedAmountInSlotLess);
        assertEq(expectedAmountInSlotLess, _amountToBet);
    }

    function test_Bet_CheckIfUserBetChangeOptionStatus() public {
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, FIVE_USDC);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), FIVE_USDC);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        SlotsOptionHelper.OptionStatus expectedOptionStatus =
            twoSlotsOption.getOptionStatus(lastContestID, TwoSlotsOption.SlotType.LESS, msg.sender);
        emit log_named_uint("Expected Option Status", uint256(expectedOptionStatus));
        assertTrue(SlotsOptionHelper.OptionStatus.CREATED == expectedOptionStatus);
    }

    function test_Bet_CheckIfUserBetIncreaseAmountInOption() public {
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        uint256 expectedAmountInOption =
            twoSlotsOption.getAmountBetInOption(lastContestID, TwoSlotsOption.SlotType.LESS, msg.sender);
        emit log_named_uint("Expected Amount In Option", expectedAmountInOption);
        assertEq(expectedAmountInOption, FIVE_USDC * 2);
    }

    function testFuzz_Bet_CheckIfUSDCBalancesChangeWithBet(uint256 _amountBet) public {
        _amountBet = bound(_amountBet, FIVE_USDC, ONE_MILION_USDC);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, _amountBet);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountBet);
        uint256 userBalanceBeforeBet = IERC20(_TOKEN0).balanceOf(msg.sender);
        emit log_named_uint("User Balance Before Bet", userBalanceBeforeBet);
        assertGt(userBalanceBeforeBet, 0);
        twoSlotsOption.bet(lastContestID, _amountBet, TwoSlotsOption.SlotType.LESS);
        uint256 userBalanceAfterBet = IERC20(_TOKEN0).balanceOf(msg.sender);
        emit log_named_uint("User Balance After Bet", userBalanceAfterBet);
        assertEq(userBalanceAfterBet, 0);
        uint256 contractBalanceAfterUserBet = IERC20(_TOKEN0).balanceOf(address(twoSlotsOption));
        emit log_named_uint("Contract Balance After User Bet", contractBalanceAfterUserBet);
        assertEq(contractBalanceAfterUserBet, userBalanceBeforeBet);
    }
}
