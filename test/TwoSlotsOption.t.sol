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
        uint256 totalFees = fees.collector + fees.creator + fees.resolver;
        emit log_named_uint("Amount Expected: ", totalFees);
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

    function testFuzz_GetContestFinancialData_RevertIfInsufficientAmountInSlots(
        uint256 _amountInSlotLess,
        uint256 _amountInSlotMore
    ) public {
        _amountInSlotLess = bound(_amountInSlotLess, 0, twoSlotsOption.MIN_BET() - 1);
        _amountInSlotMore = bound(_amountInSlotMore, 0, twoSlotsOption.MIN_BET() - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                TwoSlotsOption.InsufficientAmountInSlots.selector,
                _amountInSlotLess,
                _amountInSlotMore,
                twoSlotsOption.MIN_BET()
            )
        );
        twoSlotsOption.getContestFinancialData(_amountInSlotLess, _amountInSlotMore);
    }

    function testFuzz_GetContestFinancialData_CheckIfLessHaveBiggerOddWhenLessMoneyInSlot(
        uint256 _amountInSlotLess,
        uint256 _amountInSlotMore
    ) public {
        _amountInSlotLess = bound(_amountInSlotLess, TEN_THOUSAND_USDC, ONE_MILION_USDC - 1);
        _amountInSlotMore = bound(_amountInSlotMore, ONE_MILION_USDC, HUNDRED_MILION_USDC);

        TwoSlotsOption.ContestFinancialData memory contestFinancialData =
            twoSlotsOption.getContestFinancialData(_amountInSlotLess, _amountInSlotMore);

        assertGe(contestFinancialData.oddLess, contestFinancialData.oddMore);
    }

    function testFuzz_GetContestFinancialData_CheckIfMoreHaveBiggerOddWhenLessMoneyInSlot(
        uint256 _amountInSlotLess,
        uint256 _amountInSlotMore
    ) public {
        _amountInSlotMore = bound(_amountInSlotMore, FIVE_USDC, TEN_THOUSAND_USDC);
        _amountInSlotLess = bound(_amountInSlotLess, TEN_THOUSAND_USDC + 1, ONE_MILION_USDC);

        TwoSlotsOption.ContestFinancialData memory contestFinancialData =
            twoSlotsOption.getContestFinancialData(_amountInSlotLess, _amountInSlotMore);
        assertGe(contestFinancialData.oddMore, contestFinancialData.oddLess);
    }

    function testFuzz_GetContestFinancialData_AmountToShareIsBiggerThanRedisitributed(
        uint256 _amountInSlotLess,
        uint256 _amountInSlotMore
    ) public {
        _amountInSlotLess = bound(_amountInSlotLess, FIVE_USDC, HUNDRED_MILION_USDC);
        _amountInSlotMore = bound(_amountInSlotMore, FIVE_USDC, HUNDRED_MILION_USDC);

        TwoSlotsOption.ContestFinancialData memory contestFinancialData =
            twoSlotsOption.getContestFinancialData(_amountInSlotLess, _amountInSlotMore);

        uint256 amountRedisitributedInLess =
            (_amountInSlotLess * contestFinancialData.oddLess) / twoSlotsOption.PRECISION_FACTOR();
        uint256 amountRedisitributedInMore =
            (_amountInSlotMore * contestFinancialData.oddMore) / twoSlotsOption.PRECISION_FACTOR();

        assertGe(contestFinancialData.netToShareBetweenWinners, amountRedisitributedInLess);
        assertGe(contestFinancialData.netToShareBetweenWinners, amountRedisitributedInMore);
    }

    function testFuzz_GetContestFinancialData_AmountRemainsLowerThanOnePenny(
        uint256 _amountInSlotLess,
        uint256 _amountInSlotMore
    ) public {
        _amountInSlotLess = bound(_amountInSlotLess, FIVE_USDC, HUNDRED_MILION_USDC);
        _amountInSlotMore = bound(_amountInSlotMore, FIVE_USDC, HUNDRED_MILION_USDC);

        TwoSlotsOption.ContestFinancialData memory contestFinancialData =
            twoSlotsOption.getContestFinancialData(_amountInSlotLess, _amountInSlotMore);
        uint256 amountRedisitributedInLess =
            (_amountInSlotLess * contestFinancialData.oddLess) / twoSlotsOption.PRECISION_FACTOR();
        uint256 amountRedisitributedInMore =
            (_amountInSlotMore * contestFinancialData.oddMore) / twoSlotsOption.PRECISION_FACTOR();
        uint256 amountRemainsInLess = contestFinancialData.netToShareBetweenWinners - amountRedisitributedInLess;
        uint256 amountRemainsInMore = contestFinancialData.netToShareBetweenWinners - amountRedisitributedInMore;
        uint256 ONE_PENNY = 1e3;

        assertLt(amountRemainsInLess, ONE_PENNY);
        assertLt(amountRemainsInMore, ONE_PENNY);
    }

    function test_IsContestRefundable_CheckIfTrueWhenTwoSlotsLowerThanMinBet() public {
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 startingPrice = twoSlotsOption.getContestStartingPrice(lastContestID);
        uint256 maturityPrice = startingPrice + FIVE_USDC;
        vm.startPrank(msg.sender);
        bool contestRefundable = twoSlotsOption.isContestRefundable(lastContestID, maturityPrice);
        assertTrue(contestRefundable);
    }

    function testFuzz_IsContestRefundableBecauseSlotsAmount_CheckIfTrueWhenSlotLessLowerThanMinBet(uint256 _amountToBet)
        public
    {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        uint256 startingPrice = twoSlotsOption.getContestStartingPrice(lastContestID);
        uint256 maturityPrice = startingPrice + FIVE_USDC;
        deal(_TOKEN0, msg.sender, _amountToBet);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountToBet);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.MORE);
        bool contestRefundable = twoSlotsOption.isContestRefundable(lastContestID, maturityPrice);
        assertTrue(contestRefundable);
    }

    function testFuzz_IsContestRefundable_CheckIfTrueWhenSlotMoreLowerThanMinBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        uint256 startingPrice = twoSlotsOption.getContestStartingPrice(lastContestID);
        uint256 maturityPrice = startingPrice + FIVE_USDC;
        deal(_TOKEN0, msg.sender, _amountToBet);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountToBet);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
        bool contestRefundable = twoSlotsOption.isContestRefundable(lastContestID, maturityPrice);
        assertTrue(contestRefundable);
    }

    function testFuzz_IsContestRefundable_CheckIfFalseWhenTwoSlotsBiggerThanMinBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        uint256 startingPrice = twoSlotsOption.getContestStartingPrice(lastContestID);
        uint256 maturityPrice = startingPrice + FIVE_USDC;
        deal(_TOKEN0, msg.sender, _amountToBet * 2);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountToBet * 2);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.MORE);
        bool contestRefundable = twoSlotsOption.isContestRefundable(lastContestID, maturityPrice);
        assertFalse(contestRefundable);
    }

    function testFuzz_IsContestRefundable_CheckIfTrueWhenPricesEquals(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        uint256 startingPrice = twoSlotsOption.getContestStartingPrice(lastContestID);
        uint256 maturityPrice = startingPrice;
        deal(_TOKEN0, msg.sender, _amountToBet * 2);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountToBet * 2);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.MORE);
        bool contestRefundable = twoSlotsOption.isContestRefundable(lastContestID, maturityPrice);
        assertTrue(contestRefundable);
    }

    function testFuzz_IsContestRefundable_CheckIfFalseWhenPricesNotEquals(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        uint256 startingPrice = twoSlotsOption.getContestStartingPrice(lastContestID);
        uint256 maturityPrice = startingPrice + FIVE_USDC;
        deal(_TOKEN0, msg.sender, _amountToBet * 2);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), _amountToBet * 2);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, _amountToBet, TwoSlotsOption.SlotType.MORE);
        bool contestRefundable = twoSlotsOption.isContestRefundable(lastContestID, maturityPrice);
        assertFalse(contestRefundable);
    }

    function test_CloseContest_RevertIfContestNotOpen() public {
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.expectRevert(TwoSlotsOption.ContestNotOpen.selector);
        twoSlotsOption.closeContest(lastContestID + 1);
    }

    function test_CloseContest_RevertIfContestNotMature() public {
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.warp(_FIRST_MAY_2023 + 12 minutes);
        uint256 nowTimestamp = block.timestamp;
        uint256 maturityAt = twoSlotsOption.getContestMaturityAtTimestamp(lastContestID);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.OPEN;
        SlotsOptionHelper.ContestStatus status = twoSlotsOption.getContestStatus(lastContestID);

        assertEq(uint8(expectedStatus), uint8(status));
        assertLt(nowTimestamp, maturityAt);
        vm.expectRevert(abi.encodeWithSelector(TwoSlotsOption.ContestNotMature.selector, block.timestamp, maturityAt));
        twoSlotsOption.closeContest(lastContestID);
    }

    function test_CloseContest_CheckIfContestStatusRefundableWhenEqualsStartAndMaturityPrice() public {
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(lastContestID);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.REFUNDABLE;
        SlotsOptionHelper.ContestStatus status = twoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(expectedStatus), uint8(status));
    }

    function test_MOCKED_CloseContest_CheckIfContestStatusRefundableWhenNoBetInOneSlot() public {
        vm.warp(_FIRST_MAY_2023);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(lastContestID, FIVE_USDC, false);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.REFUNDABLE;
        SlotsOptionHelper.ContestStatus status = MOCK_TwoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(expectedStatus), uint8(status));
    }

    function test_MOCKED_CloseContest_CheckIfContestStatusResolvedWhenNotEqualsStartAndMaturityPrice() public {
        vm.warp(_FIRST_MAY_2023);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(lastContestID, FIVE_USDC, false);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.RESOLVED;
        SlotsOptionHelper.ContestStatus status = MOCK_TwoSlotsOption.getContestStatus(lastContestID);
        emit log_named_uint("Contest Status", uint8(status));
        uint256 startingPrice = MOCK_TwoSlotsOption.getContestStartingPrice(lastContestID);
        emit log_named_uint("startingPrice", startingPrice);
        uint256 maturityPrice = MOCK_TwoSlotsOption.getContestMaturityPrice(lastContestID);
        emit log_named_uint("maturityPrice", maturityPrice);
        assertEq(uint8(expectedStatus), uint8(status));
    }

    function test_MOCKED_CloseContest_CheckIfOddsAreMoreThan0WhenResolved() public {
        vm.warp(_FIRST_MAY_2023);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(lastContestID, FIVE_USDC, true);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.RESOLVED;
        SlotsOptionHelper.ContestStatus status = MOCK_TwoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(expectedStatus), uint8(status));

        uint256 payoutLess = MOCK_TwoSlotsOption.getContestPayout(lastContestID, MockTwoSlotsOption.SlotType.LESS);
        emit log_named_uint("Payout Less", payoutLess);
        uint256 payoutMore = MOCK_TwoSlotsOption.getContestPayout(lastContestID, MockTwoSlotsOption.SlotType.MORE);
        emit log_named_uint("Payout Less", payoutMore);
        assertGt(payoutLess, 0);
        assertGt(payoutMore, 0);
    }

    function test_MOCKED_CloseContest_CheckWinningSlotStatusWhenMoreWin() public {
        vm.warp(_FIRST_MAY_2023);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(lastContestID, FIVE_USDC, true);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.RESOLVED;
        SlotsOptionHelper.ContestStatus status = MOCK_TwoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(expectedStatus), uint8(status));
        MockTwoSlotsOption.WinningSlot expectedWinningSlot = MockTwoSlotsOption.WinningSlot.MORE;
        MockTwoSlotsOption.WinningSlot winningSlot = MOCK_TwoSlotsOption.getContestWinningSlot(lastContestID);
        assertEq(uint8(expectedWinningSlot), uint8(winningSlot));
        emit log_named_uint("winningSlot", uint8(winningSlot));
    }

    function test_MOCKED_CloseContest_CheckWinningSlotStatusWhenLessWin() public {
        vm.warp(_FIRST_MAY_2023);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(msg.sender);
        deal(_TOKEN0, msg.sender, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(lastContestID, FIVE_USDC, false);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.RESOLVED;
        SlotsOptionHelper.ContestStatus status = MOCK_TwoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(expectedStatus), uint8(status));
        MockTwoSlotsOption.WinningSlot expectedWinningSlot = MockTwoSlotsOption.WinningSlot.LESS;
        MockTwoSlotsOption.WinningSlot winningSlot = MOCK_TwoSlotsOption.getContestWinningSlot(lastContestID);
        assertEq(uint8(expectedWinningSlot), uint8(winningSlot));
        emit log_named_uint("winningSlot", uint8(winningSlot));
    }

    function test_MOCKED_CloseContest_CheckFeeDistribution() public {
        vm.warp(_FIRST_MAY_2023);
        vm.startPrank(alice);
        MOCK_TwoSlotsOption.createContest();
        vm.stopPrank();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();

        vm.startPrank(wojak);
        deal(_TOKEN0, wojak, ONE_MILION_USDC);
        uint256 wojakBalanceBeforeBet = IERC20(_TOKEN0).balanceOf(wojak);
        emit log_named_uint("Wojak Balance Before Bet", wojakBalanceBeforeBet);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, ONE_MILION_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        uint256 wojakBalanceAfterBet = IERC20(_TOKEN0).balanceOf(wojak);
        emit log_named_uint("Wojak Balance After Bet", wojakBalanceAfterBet);

        vm.startPrank(milady);
        deal(_TOKEN0, milady, ONE_MILION_USDC);
        uint256 miladyBalanceBeforeBet = IERC20(_TOKEN0).balanceOf(milady);
        emit log_named_uint("Wojak Balance After Bet", miladyBalanceBeforeBet);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, ONE_MILION_USDC, MockTwoSlotsOption.SlotType.MORE);
        vm.stopPrank();
        uint256 miladyBalanceAfterBet = IERC20(_TOKEN0).balanceOf(milady);
        emit log_named_uint("Milady Balance After Bet", miladyBalanceAfterBet);

        uint256 contractBalanceBeforeClose = IERC20(_TOKEN0).balanceOf(address(MOCK_TwoSlotsOption));
        emit log_named_uint("Contract Balance Before Close & After Bet", contractBalanceBeforeClose);
        uint256 collectorBalanceBeforeClose = IERC20(_TOKEN0).balanceOf(_FEE_COLLECTOR);
        emit log_named_uint("Collector Balance Before Close & After Bet", collectorBalanceBeforeClose);
        uint256 creatorBalanceBeforeClose = IERC20(_TOKEN0).balanceOf(alice);
        emit log_named_uint("Creator (Alice) Balance Before Close & After Bet", creatorBalanceBeforeClose);
        uint256 resolverBalanceBeforeClose = IERC20(_TOKEN0).balanceOf(bob);
        emit log_named_uint("Resolver (Bob) Balance Before Close & After Bet", resolverBalanceBeforeClose);

        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        vm.startPrank(bob);
        MOCK_TwoSlotsOption.mockCloseContest(lastContestID, FIVE_USDC, false);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.RESOLVED;
        SlotsOptionHelper.ContestStatus status = MOCK_TwoSlotsOption.getContestStatus(lastContestID);
        vm.stopPrank();
        assertEq(uint8(expectedStatus), uint8(status));
        assertEq(alice, MOCK_TwoSlotsOption.getContestCreator(lastContestID));
        assertEq(bob, MOCK_TwoSlotsOption.getContestResolver(lastContestID));

        uint256 contractBalanceAfterClose = IERC20(_TOKEN0).balanceOf(address(MOCK_TwoSlotsOption));
        emit log_named_uint("Contract Balance After Close", contractBalanceAfterClose);
        uint256 collectorBalanceAfterClose = IERC20(_TOKEN0).balanceOf(_FEE_COLLECTOR);
        emit log_named_uint("Collector Balance After Close", collectorBalanceAfterClose);
        uint256 creatorBalanceAfterClose = IERC20(_TOKEN0).balanceOf(alice);
        emit log_named_uint("Creator (Alice) Balance After Close", creatorBalanceAfterClose);
        uint256 resolverBalanceAfterClose = IERC20(_TOKEN0).balanceOf(bob);
        emit log_named_uint("Resolver (Bob) Balance After Close", resolverBalanceAfterClose);

        assertLt(contractBalanceAfterClose, contractBalanceBeforeClose);
        assertGt(collectorBalanceAfterClose, collectorBalanceBeforeClose);
        assertGt(creatorBalanceAfterClose, creatorBalanceBeforeClose);
        assertGt(resolverBalanceAfterClose, resolverBalanceBeforeClose);
    }

    function test_ClaimContest_RevertIfContestNotClose() public {
        vm.warp(_FIRST_MAY_2023);
        SlotsOptionHelper.ContestStatus contestUndefined = SlotsOptionHelper.ContestStatus.UNDEFINED;
        SlotsOptionHelper.ContestStatus statusContestTen = twoSlotsOption.getContestStatus(10);
        assertEq(uint8(contestUndefined), uint8(statusContestTen));
        emit log_named_uint("status Contest id-10", uint8(statusContestTen));

        vm.expectRevert(TwoSlotsOption.ContestNotClose.selector);
        twoSlotsOption.claimContest(10);

        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        SlotsOptionHelper.ContestStatus contestOpen = SlotsOptionHelper.ContestStatus.OPEN;
        SlotsOptionHelper.ContestStatus statusContestLastOpen = twoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(contestOpen), uint8(statusContestLastOpen));
        emit log_named_uint("status Contest id-1", uint8(statusContestLastOpen));

        vm.expectRevert(TwoSlotsOption.ContestNotClose.selector);
        twoSlotsOption.claimContest(lastContestID);
    }

    function test_ClaimContest_RevertIfUserHaveNothingToClaim() public {
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        SlotsOptionHelper.ContestStatus contestOpen = SlotsOptionHelper.ContestStatus.OPEN;
        SlotsOptionHelper.ContestStatus statusContestLastOpen = twoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(contestOpen), uint8(statusContestLastOpen));
        emit log_named_uint("status Contest id-1", uint8(statusContestLastOpen));
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(lastContestID);
        SlotsOptionHelper.ContestStatus contestRefundable = SlotsOptionHelper.ContestStatus.REFUNDABLE;
        SlotsOptionHelper.ContestStatus newStatusContestLastOpen = twoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(contestRefundable), uint8(newStatusContestLastOpen));
        emit log_named_uint("status Contest id-1", uint8(newStatusContestLastOpen));
        vm.expectRevert(TwoSlotsOption.UserHaveNothingToClaim.selector);
        twoSlotsOption.claimContest(lastContestID);
    }

    function test_ClaimContest_AmountToClaimIsGoodWhenRefundedBecauseEqualsStartAndMaturityPrice() public {
        vm.warp(_FIRST_MAY_2023);
        twoSlotsOption.createContest();
        uint256 lastContestID = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        vm.startPrank(wojak);
        deal(_TOKEN0, wojak, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(lastContestID, ONE_MILION_USDC, TwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(milady);
        deal(_TOKEN0, milady, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(twoSlotsOption), ONE_MILION_USDC);
        twoSlotsOption.bet(lastContestID, TEN_THOUSAND_USDC, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, FIVE_USDC, TwoSlotsOption.SlotType.LESS);
        twoSlotsOption.bet(lastContestID, TEN_THOUSAND_USDC, TwoSlotsOption.SlotType.MORE);
        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        twoSlotsOption.closeContest(lastContestID);
        uint256 startingPrice = twoSlotsOption.getContestStartingPrice(lastContestID);
        uint256 maturityPrice = twoSlotsOption.getContestMaturityPrice(lastContestID);
        assertEq(startingPrice, maturityPrice);
        SlotsOptionHelper.ContestStatus contestRefundable = SlotsOptionHelper.ContestStatus.REFUNDABLE;
        SlotsOptionHelper.ContestStatus newStatusContestLastOpen = twoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(contestRefundable), uint8(newStatusContestLastOpen));
        uint256 contractBalanceBeforeMiladyClaim = IERC20(_TOKEN0).balanceOf(address(twoSlotsOption));
        emit log_named_uint("Contract Balance Before MiladyClaim", contractBalanceBeforeMiladyClaim);
        assertEq(contractBalanceBeforeMiladyClaim, ONE_MILION_USDC + TEN_THOUSAND_USDC * 2 + FIVE_USDC);
        uint256 miladyBalanceBeforeClaim = IERC20(_TOKEN0).balanceOf(milady);
        emit log_named_uint("Milady Balance Before Claim", miladyBalanceBeforeClaim);
        twoSlotsOption.claimContest(lastContestID);
        vm.stopPrank();
        uint256 miladyBalanceAfterClaim = IERC20(_TOKEN0).balanceOf(milady);
        emit log_named_uint("Milady Balance After Claim", miladyBalanceAfterClaim);
        assertEq(miladyBalanceAfterClaim, ONE_MILION_USDC);
        uint256 contractBalanceAfterMiladyClaim = IERC20(_TOKEN0).balanceOf(address(twoSlotsOption));
        emit log_named_uint("Contract Balance After Milady Claim", contractBalanceAfterMiladyClaim);
        assertEq(contractBalanceAfterMiladyClaim, ONE_MILION_USDC);
        uint256 wojakBalanceBeforeClaim = IERC20(_TOKEN0).balanceOf(wojak);
        emit log_named_uint("Wojak Balance Before Claim", wojakBalanceBeforeClaim);
        assertEq(wojakBalanceBeforeClaim, 0);
        vm.startPrank(wojak);
        twoSlotsOption.claimContest(lastContestID);
        uint256 wojakBalanceAfterClaim = IERC20(_TOKEN0).balanceOf(wojak);
        emit log_named_uint("Wojak Balance After Claim", wojakBalanceAfterClaim);
        assertEq(wojakBalanceAfterClaim, ONE_MILION_USDC);
        uint256 contractBalanceAfterWojakClaim = IERC20(_TOKEN0).balanceOf(address(twoSlotsOption));
        emit log_named_uint("Contract Balance After Wojak Claim", contractBalanceAfterWojakClaim);
        assertEq(contractBalanceAfterWojakClaim, 0);
    }

    function test_MOCKED_ClaimContest_AmountToClaimIsGoodWhenRefundedBecauseAmountOnlyInOneSlot() public {
        vm.warp(_FIRST_MAY_2023);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();

        vm.startPrank(wojak);
        deal(_TOKEN0, wojak, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, ONE_MILION_USDC, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(milady);
        deal(_TOKEN0, milady, ONE_MILION_USDC);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), ONE_MILION_USDC);
        MOCK_TwoSlotsOption.bet(lastContestID, TEN_THOUSAND_USDC, MockTwoSlotsOption.SlotType.LESS);
        MOCK_TwoSlotsOption.bet(lastContestID, FIVE_USDC, MockTwoSlotsOption.SlotType.LESS);

        vm.warp(_FIRST_MAY_2023 + 22 minutes);
        MOCK_TwoSlotsOption.mockCloseContest(lastContestID, FIVE_USDC, false);
        uint256 startingPrice = MOCK_TwoSlotsOption.getContestStartingPrice(lastContestID);
        uint256 maturityPrice = MOCK_TwoSlotsOption.getContestMaturityPrice(lastContestID);
        assertTrue(startingPrice != maturityPrice);
        SlotsOptionHelper.ContestStatus expectedStatus = SlotsOptionHelper.ContestStatus.REFUNDABLE;
        SlotsOptionHelper.ContestStatus status = MOCK_TwoSlotsOption.getContestStatus(lastContestID);
        assertEq(uint8(expectedStatus), uint8(status));

        uint256 contractBalanceBeforeMiladyClaim = IERC20(_TOKEN0).balanceOf(address(MOCK_TwoSlotsOption));
        emit log_named_uint("Contract Balance Before MiladyClaim", contractBalanceBeforeMiladyClaim);
        assertEq(contractBalanceBeforeMiladyClaim, ONE_MILION_USDC + TEN_THOUSAND_USDC + FIVE_USDC);
        uint256 miladyBalanceBeforeClaim = IERC20(_TOKEN0).balanceOf(milady);
        emit log_named_uint("Milady Balance Before Claim", miladyBalanceBeforeClaim);
        MOCK_TwoSlotsOption.claimContest(lastContestID);
        vm.stopPrank();
        uint256 miladyBalanceAfterClaim = IERC20(_TOKEN0).balanceOf(milady);
        emit log_named_uint("Milady Balance After Claim", miladyBalanceAfterClaim);
        assertEq(miladyBalanceAfterClaim, ONE_MILION_USDC);
        uint256 contractBalanceAfterMiladyClaim = IERC20(_TOKEN0).balanceOf(address(MOCK_TwoSlotsOption));
        emit log_named_uint("Contract Balance After Milady Claim", contractBalanceAfterMiladyClaim);
        assertEq(contractBalanceAfterMiladyClaim, ONE_MILION_USDC);
        uint256 wojakBalanceBeforeClaim = IERC20(_TOKEN0).balanceOf(wojak);
        emit log_named_uint("Wojak Balance Before Claim", wojakBalanceBeforeClaim);
        assertEq(wojakBalanceBeforeClaim, 0);
        vm.startPrank(wojak);
        MOCK_TwoSlotsOption.claimContest(lastContestID);
        uint256 wojakBalanceAfterClaim = IERC20(_TOKEN0).balanceOf(wojak);
        emit log_named_uint("Wojak Balance After Claim", wojakBalanceAfterClaim);
        assertEq(wojakBalanceAfterClaim, ONE_MILION_USDC);
        uint256 contractBalanceAfterWojakClaim = IERC20(_TOKEN0).balanceOf(address(MOCK_TwoSlotsOption));
        emit log_named_uint("Contract Balance After Wojak Claim", contractBalanceAfterWojakClaim);
        assertEq(contractBalanceAfterWojakClaim, 0);
    }
}
