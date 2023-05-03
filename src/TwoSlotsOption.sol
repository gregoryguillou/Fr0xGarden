// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TwoSlotsOption
/// @author @fr0xMaster
/// @notice Mutual Slots implementation of Two Slots Option contract.
contract TwoSlotsOption is Ownable {
    /// @notice Status of an Option. The status can alternate between 3 different states.
    /// OPEN is the default status when a new option is created. In this status, if the contest is not mature, users can bet on a slot.
    /// RESOLVED is the status assigned once the option has reached maturity and a winning slot has been determined in favor of a loser.
    /// REFUNDABLE is the status assigned once the option has reached its maturity but the conditions are not met to determine a winner.
    enum OptionStatus {
        OPEN,
        RESOLVED,
        REFUNDABLE
    }

    enum BetStatus {
        OPEN,
        CLAIMED,
        REFUND
    }

    enum WinningSlot {
        UNDEFINED,
        LESS,
        MORE
    }

    struct Option {
        OptionStatus optionStatus; // Status of the current option
        address creator; // Address who created option. Will receive a share of the fees generated.
        address resolver; // Address who resolve option. Will receive a share of the fees generated.
        uint64 startedAt; // Unix timestamp at option creation
        uint64 maturityAt; // Unix timestamp at option maturity
        uint256 startingPrice; // Token price at option creation
        uint256 maturyityPrice; // Token price at option maturity
        WinningSlot winningSlot;
        Slot[2] slot;
    }

    struct Slot {
        uint256 totalAmount;
        uint256 payout;
        mapping(address => Bet) bets;
    }

    struct Bet {
        BetStatus betStatus;
        uint256 amount;
    }
}
