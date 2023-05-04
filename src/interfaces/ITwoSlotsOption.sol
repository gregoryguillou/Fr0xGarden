// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
pragma solidity ^0.8.17;

interface ITwoSlotsOption {
    enum ContestStatus {
        OPEN,
        RESOLVED,
        REFUNDABLE
    }
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

    event CreateContest(uint256 indexed _contestID, address indexed _creator);

    function getContestStatus(uint256 _contestID) external view returns (ContestStatus);

    function getContestStartingPrice(uint256 _contestID) external view returns (uint256);

    function createContest() external returns (bool);
}
