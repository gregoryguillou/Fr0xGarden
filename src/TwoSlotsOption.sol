// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UniswapV3TWAP} from "src/UniswapV3TWAP.sol";

/// @title TwoSlotsOption
/// @author @fr0xMaster
/// @notice Mutual Slots implementation of Two Slots Option contract.

contract TwoSlotsOption is Ownable {
    address public immutable FACTORY;
    address public immutable TOKEN0;
    address public immutable TOKEN1;
    uint24 public UNISWAP_POOL_FEE;
    UniswapV3TWAP uniswapV3TWAP;
    address public FEES_COLLECTOR; //address who receives fees generated by contract activity
    uint256 public MIN_BET; //minimum amount to bet
    uint256 public MAX_BET; //maximum amount to bet
    uint8 public FEE_NUMERATOR; //numerator to calculate fees
    uint8 public FEE_DENOMINATOR; //denominator to calculate fees
    uint256 public EPOCH; //duration of an epoch expressed in seconds
    uint256 public LAST_OPEN_CONTEST_ID; // ID of last contest open.
    uint256 public lastCloseContestID; // ID of last contest close. To be close a contest need to be Resolved or Refundable
    mapping(uint256 => Contest) contests; //mapping of all contests formatted as struct.

    //TODO Add a link to the desired contract token (arb,eth,etc..)

    constructor(
        address _FACTORY,
        address _TOKEN0,
        address _TOKEN1,
        uint24 _UNISWAP_POOL_FEE,
        address _FEES_COLLECTOR,
        uint8 _FEE_NUMERATOR,
        uint8 _FEE_DENOMINATOR,
        uint256 _MIN_BET,
        uint256 _MAX_BET,
        uint64 _EPOCH
    ) {
        FACTORY = _FACTORY;
        TOKEN0 = _TOKEN0;
        TOKEN1 = _TOKEN1;
        UNISWAP_POOL_FEE = _UNISWAP_POOL_FEE;
        FEES_COLLECTOR = _FEES_COLLECTOR;
        FEE_NUMERATOR = _FEE_NUMERATOR;
        FEE_DENOMINATOR = _FEE_DENOMINATOR;
        MIN_BET = _MIN_BET;
        MAX_BET = _MAX_BET;
        EPOCH = _EPOCH;
        uniswapV3TWAP = new UniswapV3TWAP(FACTORY, TOKEN0,TOKEN1,UNISWAP_POOL_FEE);
    }

    /// @notice Status of a Contest. The status can alternate between 3 different states.
    // OPEN is the default status when a new Contest is created. In this status, if the contest is not mature, users can buy a slot option.
    // RESOLVED is the status assigned once the Contest has reached maturity and a winning slot has been determined in favor of a loser.
    // REFUNDABLE is the status assigned once the v has reached its maturity but the conditions are not met to determine a winner.
    enum ContestStatus {
        OPEN,
        RESOLVED,
        REFUNDABLE
    }

    /// @notice Status of an Option. The status can alternate between 3 different states.
    // CREATED is the default status when a new Option is created. This status defines that an Option has been created and is attached to an address.
    // CLAIMED status is assigned to a winning Option and claimed by the linked address.
    // REFUND status is assigned when an Option has no winner and the linked address has been refunded its initial Option.
    enum OptionStatus {
        CREATED,
        CLAIMED,
        REFUND
    }

    enum WinningSlot {
        UNDEFINED,
        LESS,
        MORE
    }

    struct Option {
        OptionStatus optionStatus;
        uint256 amount;
    }

    struct Slot {
        uint256 totalAmount;
        uint256 payout;
        mapping(address => Option) options;
    }

    struct Contest {
        ContestStatus contestStatus; // Status of the current Contest
        uint256 startedAt; // Unix timestamp at contest creation
        uint256 closeAt; // Unix timestamp at deposit is closed
        uint256 maturityAt; // Unix timestamp at contest maturity
        address creator; // Address who created contest. Will receive a share of the fees generated.
        address resolver; // Address who resolve contest. Will receive a share of the fees generated.
        uint256 startingPrice; // Token price at contest creation
        uint256 maturyityPrice; // Token price at contest maturity
        WinningSlot winningSlot; // Defines the winning slot once the Contest is resolved
        Slot slotLess;
        Slot slotMore;
    }

    error ContestIsAlreadyOpen(uint256 LAST_OPEN_CONTEST_ID);

    modifier isCreateable() {
        if (
            contests[LAST_OPEN_CONTEST_ID].contestStatus == ContestStatus.OPEN
                && block.timestamp < contests[LAST_OPEN_CONTEST_ID].closeAt
        ) {
            revert ContestIsAlreadyOpen(LAST_OPEN_CONTEST_ID);
        }
        _;
    }

    event CreateContest(uint256 indexed _contestID, address indexed _creator);

    /// @notice Calculate fees to be deducted from a given amount
    /// @dev Fee amount by dividing the numerator by the denominator which - e.g: 3/100 = 0.03 or 3% percent;
    /// @param _amount amount between 1e15 & 1e20.
    /// @return fees amount in wei
    function getFeeByAmount(uint96 _amount) public view returns (uint256) {
        return _amount * FEE_NUMERATOR / FEE_DENOMINATOR;
    }

    function setLastOpenContestID(uint256 _id) internal {
        LAST_OPEN_CONTEST_ID = _id;
    }

    function getContestStatus(uint256 _contestID) external view returns (ContestStatus) {
        return contests[_contestID].contestStatus;
    }

    function getContestStartingPrice(uint256 _contestID) external view returns (uint256) {
        return contests[_contestID].startingPrice;
    }

    function getContestCloseAtTimestamp(uint256 _contestID) external view returns (uint256) {
        return contests[_contestID].closeAt;
    }

    function getContestMaturityAtTimestamp(uint256 _contestID) external view returns (uint256) {
        return contests[_contestID].maturityAt;
    }

    function createContest() external isCreateable returns (bool) {
        uint256 newContestID = LAST_OPEN_CONTEST_ID + 1;
        contests[newContestID].contestStatus = ContestStatus.OPEN;
        contests[newContestID].startedAt = block.timestamp;
        contests[newContestID].closeAt = block.timestamp + EPOCH;
        contests[newContestID].maturityAt = block.timestamp + (EPOCH * 2);
        contests[newContestID].creator = msg.sender;
        contests[newContestID].startingPrice = uniswapV3TWAP.estimateAmountOut(TOKEN1, 10 ** 18, 32);
        setLastOpenContestID(newContestID);
        emit CreateContest(newContestID, msg.sender);
        return true;
    }
}
