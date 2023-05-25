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

contract TwoSlotsOptionTestCreateContest is Test {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    TwoSlotsOption public twoSlotsOption;
    uint256 _arbitrumFork;
    uint256 _FIRST_MAY_2023 = 1682892000;
    address _FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // address of UNISWAP V3 _FACTORY on Arbitrum network.
    address _TOKEN0 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC on Arbitrum network
    address _TOKEN1 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum network
    uint256 public constant FIVE_USDC = 5 * 1e6; // 5 dollars in USDC  exponential notation of 6 decimals to assign MIN BET
    uint24 _UNISWAP_POOL_FEE = 3000;
    uint8 public SECONDS_FOR_ORACLE_TWAP = 6;
    uint8 public FEE_COLLECTOR_NUMERATOR = 3; // numerator to calculate fees
    uint8 public FEE_CREATOR_NUMERATOR = 2; // numerator to calculate fees
    uint8 public FEE_RESOLVER_NUMERATOR = 8; // numerator to calculate fees
    uint8 public FEE_DENOMINATOR = 100; // denominator to calculate fees
    uint256 public EPOCH = 10 minutes; // duration of an epoch expressed in seconds
    address _FEE_COLLECTOR = 0x00000000000000000000000000000000DeaDBeef;
    address public alice = makeAddr("alice");

    function setUp() public {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        _arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(_arbitrumFork);
        twoSlotsOption =
        new TwoSlotsOption(_FEE_COLLECTOR,_FACTORY,_TOKEN0,_TOKEN1,_UNISWAP_POOL_FEE, SECONDS_FOR_ORACLE_TWAP,FEE_DENOMINATOR, FEE_COLLECTOR_NUMERATOR,FEE_CREATOR_NUMERATOR ,FEE_RESOLVER_NUMERATOR, FIVE_USDC, EPOCH);
        vm.warp(_FIRST_MAY_2023);
    }

    function test_RevertIf_LastContestOpen() public {
        twoSlotsOption.createContest();
        vm.expectRevert(abi.encodeWithSelector(TwoSlotsOption.ContestIsAlreadyOpen.selector, 1));
        twoSlotsOption.createContest();
    }

    function test_RevertIf_LastContestOpenAndLessClosingTime() public {
        twoSlotsOption.createContest();
        vm.warp(_FIRST_MAY_2023 + EPOCH - 1);
        vm.expectRevert(abi.encodeWithSelector(TwoSlotsOption.ContestIsAlreadyOpen.selector, 1));
        twoSlotsOption.createContest();
    }

    function test_CheckIfContestCreatedAfterClosingTime() public {
        twoSlotsOption.createContest();
        vm.warp(_FIRST_MAY_2023 + EPOCH);
        twoSlotsOption.createContest();
        assertEq(twoSlotsOption.LAST_OPEN_CONTEST_ID(), 2);
    }

    function test_CheckIfContestCreatedWhenNoContests() public {
        uint256 expected = twoSlotsOption.LAST_OPEN_CONTEST_ID();
        assertEq(expected, 0);
        twoSlotsOption.createContest();
        assertEq(twoSlotsOption.LAST_OPEN_CONTEST_ID(), expected + 1);
    }

    function testt_CheckIfContestStatusOPEN() public {
        assertTrue(twoSlotsOption.getContestStatus(1) == SlotsOptionHelper.ContestStatus.UNDEFINED);
        twoSlotsOption.createContest();
        assertTrue(twoSlotsOption.getContestStatus(1) == SlotsOptionHelper.ContestStatus.OPEN);
    }

    function test_CheckContestStartingTime() public {
        assertEq(twoSlotsOption.getContestStartedAtTimestamp(1), 0);
        twoSlotsOption.createContest();
        assertEq(twoSlotsOption.getContestStartedAtTimestamp(1), _FIRST_MAY_2023);
    }

    function test_CheckContestClosingTime() public {
        assertEq(twoSlotsOption.getContestCloseAtTimestamp(1), 0);
        twoSlotsOption.createContest();
        assertEq(twoSlotsOption.getContestCloseAtTimestamp(1), _FIRST_MAY_2023 + EPOCH);
    }

    function test_CheckContestMaturityTime() public {
        assertEq(twoSlotsOption.getContestMaturityAtTimestamp(1), 0);
        twoSlotsOption.createContest();
        assertEq(twoSlotsOption.getContestMaturityAtTimestamp(1), _FIRST_MAY_2023 + EPOCH * 2);
    }

    function test_CheckContestCreator() public {
        assertEq(twoSlotsOption.getContestCreator(1), address(0));
        vm.prank(alice);
        twoSlotsOption.createContest();
        assertEq(twoSlotsOption.getContestCreator(1), alice);
    }

    function test_CreateContest_CheckContestStartingPrice() public {
        assertEq(twoSlotsOption.getContestStartingPrice(1), 0);
        twoSlotsOption.createContest();
        assertGe(twoSlotsOption.getContestStartingPrice(1), 0);
    }

    function test_ChecIfkWinningSlotUNDEFINED() public {
        twoSlotsOption.createContest();
        assertTrue(twoSlotsOption.getContestWinningSlot(1) == TwoSlotsOption.WinningSlot.UNDEFINED);
    }

    function test_CheckIfContestMaturityPriceEqualsZero() public {
        twoSlotsOption.createContest();
        assertEq(twoSlotsOption.getContestMaturityPrice(1), 0);
    }
}
