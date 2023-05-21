// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
pragma solidity ^0.8.17;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library SlotsOptionHelper {
    using Strings for uint256;

    /// @notice Status of a Contest. The status can alternate between 3 different states.
    // OPEN is the default status when a new Contest is created. In this status, if the contest is not mature, users can buy a slot option.
    // RESOLVED is the status assigned once the Contest has reached maturity and a winning slot has been determined in favor of a loser.
    // REFUNDABLE is the status assigned once the v has reached its maturity but the conditions are not met to determine a winner.
    enum ContestStatus {
        UNDEFINED,
        OPEN,
        RESOLVED,
        REFUNDABLE
    }
    /// @notice Status of an Option. The status can alternate between 3 different states.
    // CREATED is the default status when a new Option is created. This status defines that an Option has been created and is attached to an address.
    // CLAIMED status is assigned to a winning Option and claimed by the linked address.
    // REFUND status is assigned when an Option has no winner and the linked address has been refunded its initial Option.
    enum OptionStatus {
        UNDEFINED,
        CREATED,
        CLAIMED,
        REFUND
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

    struct Fees {
        uint256 total;
        uint256 collector;
        uint256 creator;
        uint256 resolver;
    }

    struct ContestFinancialData {
        uint256 totalGrossBet;
        Fees fees;
        uint256 netToShareBetweenWinners;
    }

    function getFee(uint256 _amount, uint8 _feeNumerator, uint8 _feeDenominator) internal pure returns (uint256) {
        return _amount * (_feeNumerator) / (_feeDenominator);
    }

    /// @notice Calculate fees to be deducted from a given amount
    /// @dev Fee amount by dividing the numerator by the denominator which - e.g: 3/100 = 0.03 or 3% percent;
    /// @param _amount amount between 1e15 & 1e20.
    /// @return fees amount in wei
    function getFeesByAmount(
        uint256 _amount,
        uint8 _feeCollectorNumerator,
        uint8 _feeCreatorNumerator,
        uint8 _feeResolverNumerator,
        uint8 _feeDenominator,
        uint256 _maxFeeCreator,
        uint256 _maxFeeResolver
    ) public pure returns (Fees memory) {
        uint256 total = getFee(_amount, _feeCollectorNumerator, _feeDenominator);
        uint256 creatorFees = getFee(total, _feeCreatorNumerator, _feeDenominator);
        uint256 resolverFees = getFee(total, _feeResolverNumerator, _feeDenominator);
        uint256 creator = creatorFees < _maxFeeCreator ? creatorFees : _maxFeeCreator;
        uint256 resolver = creatorFees < _maxFeeResolver ? resolverFees : _maxFeeResolver;
        uint256 collector = total - (creator + resolver);
        return Fees({total: total, collector: collector, creator: creator, resolver: resolver});
    }

    function numToFixedLengthStr(uint256 _decimalPlaces, uint256 _num) public pure returns (string memory) {
        bytes memory byteString;
        for (uint256 i = 0; i < _decimalPlaces; i++) {
            uint256 remainder = _num % 10;
            byteString = abi.encodePacked(remainder.toString(), byteString);
            _num = _num / 10;
        }
        return string(byteString);
    }

    function getDecimalsStringFromOdd(
        uint256 _decimalPlaces,
        uint256 _odd,
        uint256 _precisionFactor,
        uint256 _denominator
    ) public pure returns (string memory) {
        uint256 readableOdd = _odd / (_precisionFactor / 1e3); // To get number on Base 1000
        uint256 factor = 10 ** _decimalPlaces;
        uint256 quotient = readableOdd / _denominator;
        bool rounding = 2 * ((readableOdd * factor) % _denominator) >= _denominator;
        uint256 remainder = (readableOdd * factor / _denominator) % factor;
        if (rounding) {
            remainder += 1;
        }
        return string(abi.encodePacked(quotient.toString(), ".", numToFixedLengthStr(_decimalPlaces, remainder)));
    }
}
