// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
/* solhint-disable var-name-mixedcase */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockTwoSlotsOption} from "../src/Mocks/MockTwoSlotsOption.sol";

contract TwoSlotsOptionTest is Test {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    MockTwoSlotsOption public MOCK_TwoSlotsOption;
    uint256 _arbitrumFork;
    uint256 _FIRST_MAY_2023 = 1682892000;
    address _FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // address of UNISWAP V3 _FACTORY on Arbitrum network.
    address _TOKEN0 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum network
    address _TOKEN1 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum network
    uint256 public constant FIVE_USDC = 5 * 1e6; // 5 dollars in USDC  exponential notation of 6 decimals to assign MIN BET
    uint256 public constant ONE_MILION_USDC = 1_000_000 * 1e6; // 1M dollars in USDC  exponential notation of 6 decimals, to assign MAX BET
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

    function setUp() public {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        _arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(_arbitrumFork);
        MOCK_TwoSlotsOption =
        new MockTwoSlotsOption(_FEE_COLLECTOR,_FACTORY,_TOKEN0,_TOKEN1,_UNISWAP_POOL_FEE, SECONDS_FOR_ORACLE_TWAP,FEE_DENOMINATOR, FEE_COLLECTOR_NUMERATOR,FEE_CREATOR_NUMERATOR ,FEE_RESOLVER_NUMERATOR, FIVE_USDC, EPOCH);
        vm.warp(_FIRST_MAY_2023);
        deal(_TOKEN0, wojak, ONE_MILION_USDC);
        deal(_TOKEN0, alice, ONE_MILION_USDC);
    }

    function testMock_CheckIfTrueWhenNoBetsOnTwoSlots() public {
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 startingPrice = MOCK_TwoSlotsOption.getContestStartingPrice(lastContestID);
        bool contestRefundable = MOCK_TwoSlotsOption.isContestRefundable(lastContestID, startingPrice + FIVE_USDC);
        assertTrue(contestRefundable);
    }

    function testMockFuzz_CheckIfTrueWhenSlotLessLowerThanMinBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 startingPrice = MOCK_TwoSlotsOption.getContestStartingPrice(lastContestID);
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountToBet);
        MOCK_TwoSlotsOption.bet(lastContestID, _amountToBet, MockTwoSlotsOption.SlotType.MORE);
        bool contestRefundable = MOCK_TwoSlotsOption.isContestRefundable(lastContestID, startingPrice + FIVE_USDC);
        assertTrue(contestRefundable);
    }

    function testMockFuzz_CheckIfTrueWhenSlotMoreLowerThanMinBet(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 startingPrice = MOCK_TwoSlotsOption.getContestStartingPrice(lastContestID);
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountToBet);
        MOCK_TwoSlotsOption.bet(lastContestID, _amountToBet, MockTwoSlotsOption.SlotType.LESS);
        bool contestRefundable = MOCK_TwoSlotsOption.isContestRefundable(lastContestID, startingPrice + FIVE_USDC);
        assertTrue(contestRefundable);
    }

    function testMockFuzz_CheckIfTrueWhenBetsOnTwoSlotsButEqualsPrices(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 startingPrice = MOCK_TwoSlotsOption.getContestStartingPrice(lastContestID);
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountToBet);
        MOCK_TwoSlotsOption.bet(lastContestID, _amountToBet, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountToBet);
        MOCK_TwoSlotsOption.bet(lastContestID, _amountToBet, MockTwoSlotsOption.SlotType.MORE);
        bool contestRefundable = MOCK_TwoSlotsOption.isContestRefundable(lastContestID, startingPrice);
        assertTrue(contestRefundable);
    }

    function testMockFuzz_CheckIfFalseWhenContestNotRefundable(uint256 _amountToBet) public {
        _amountToBet = bound(_amountToBet, FIVE_USDC, ONE_MILION_USDC);
        MOCK_TwoSlotsOption.createContest();
        uint256 lastContestID = MOCK_TwoSlotsOption.LAST_OPEN_CONTEST_ID();
        uint256 startingPrice = MOCK_TwoSlotsOption.getContestStartingPrice(lastContestID);
        vm.startPrank(alice);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountToBet);
        MOCK_TwoSlotsOption.bet(lastContestID, _amountToBet, MockTwoSlotsOption.SlotType.LESS);
        vm.stopPrank();
        vm.startPrank(wojak);
        IERC20(_TOKEN0).approve(address(MOCK_TwoSlotsOption), _amountToBet);
        MOCK_TwoSlotsOption.bet(lastContestID, _amountToBet, MockTwoSlotsOption.SlotType.MORE);
        bool contestRefundable = MOCK_TwoSlotsOption.isContestRefundable(lastContestID, startingPrice + FIVE_USDC);
        assertFalse(contestRefundable);
    }
}
