// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
/* solhint-disable var-name-mixedcase */
/* solhint-disable func-param-name-mixedcase */
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SlotsOptionHelper} from "../Libraries/SlotsOptionHelper.sol";
import {UniswapV3TWAP} from "../UniswapV3TWAP.sol";

/// @title TwoSlotsOption
/// @author @fr0xMaster
/// @notice MOCK VERSION of Mutual Slots implementation of Two Slots Option contract To Help Testing Logic without integration limitations.

// TODO: Put function setter on Global variable to change FeeCollector,  Fee numerator, etc...;
// TODO: change usage of '1ether' in estimateAmountOut call to let possibility to do it with erc20 token
//TODO: add  MAX_FEE_CREATOR AND MAX_FEE_RESOLVER and setter to have flexibility and avoid stack too deep error in constructor
// TODO: add modifier to check before first bet is created all state var not in constrcuor are all sets !!

contract MockTwoSlotsOption is Ownable {
    using SafeERC20 for IERC20;

    address public FEES_COLLECTOR; // address who receives fees generated by contract activity
    address public immutable FACTORY; // address of UNISWAP V3 FACTORY.
    address public immutable TOKEN0; // address of USDC Token
    address public immutable TOKEN1; // address of ERC20 Token use for Options (ex. ETH, ARB, WBTC,...)
    uint24 public UNISWAP_POOL_FEE; // fees of the desired Uniswap pool in order to use the V3 oracle features
    uint8 public SECONDS_FOR_ORACLE_TWAP; // fees of the desired Uniswap pool in order to use the V3 oracle features
    UniswapV3TWAP internal _uniswapV3TWAP;
    uint256 public MIN_BET; // minimum amount to bet - to avoid spam attack & underflow
    uint256 public PRECISION_FACTOR = 1e12; // used to allow for better accuracy of odds and redistribution of winnings
    uint8 public FEE_DENOMINATOR; // denominator to calculate fees
    uint8 public FEE_COLLECTOR_NUMERATOR; // numerator to calculate fees for collector
    uint8 public FEE_CREATOR_NUMERATOR; // numerator to calculate fees for creator
    uint8 public FEE_RESOLVER_NUMERATOR; // numerator to calculate fees for resolver
    uint64 public MAX_FEE_CREATOR = 5 * 1e6;
    uint64 public MAX_FEE_RESOLVER = 50 * 1e6;
    uint256 public EPOCH; // duration of an epoch expressed in seconds
    uint256 public LAST_OPEN_CONTEST_ID; // ID of last contest open.
    mapping(uint256 => Contest) internal _contests; // mapping of all contests formatted as struct.

    constructor(
        address _FEES_COLLECTOR,
        address _FACTORY,
        address _TOKEN0,
        address _TOKEN1,
        uint24 _UNISWAP_POOL_FEE,
        uint8 _SECONDS_FOR_ORACLE_TWAP,
        uint8 _FEE_DENOMINATOR,
        uint8 _FEE_COLLECTOR_NUMERATOR,
        uint8 _FEE_CREATOR_NUMERATOR,
        uint8 _FEE_RESOLVER_NUMERATOR,
        uint256 _MIN_BET,
        uint256 _EPOCH
    ) {
        FEES_COLLECTOR = _FEES_COLLECTOR;
        FACTORY = _FACTORY;
        TOKEN0 = _TOKEN0;
        TOKEN1 = _TOKEN1;
        UNISWAP_POOL_FEE = _UNISWAP_POOL_FEE;
        SECONDS_FOR_ORACLE_TWAP = _SECONDS_FOR_ORACLE_TWAP;
        FEE_DENOMINATOR = _FEE_DENOMINATOR;
        FEE_COLLECTOR_NUMERATOR = _FEE_COLLECTOR_NUMERATOR;
        FEE_CREATOR_NUMERATOR = _FEE_CREATOR_NUMERATOR;
        FEE_RESOLVER_NUMERATOR = _FEE_RESOLVER_NUMERATOR;
        MIN_BET = _MIN_BET;
        EPOCH = _EPOCH;
        _uniswapV3TWAP = new UniswapV3TWAP(FACTORY, TOKEN0,TOKEN1,UNISWAP_POOL_FEE);
    }

    enum SlotType {
        LESS,
        MORE
    }
    enum WinningSlot {
        UNDEFINED,
        LESS,
        MORE
    }

    struct Contest {
        SlotsOptionHelper.ContestStatus contestStatus; // Status of the current Contest
        uint256 startedAt; // Unix timestamp at contest creation
        uint256 closeAt; // Unix timestamp at deposit is closed
        uint256 maturityAt; // Unix timestamp at contest maturity
        address creator; // Address who created contest. Will receive a share of the fees generated.
        address resolver; // Address who resolve contest. Will receive a share of the fees generated.
        uint256 startingPrice; // Token price at contest creation
        uint256 maturityPrice; // Token price at contest maturity
        WinningSlot winningSlot; // Defines the winning slot once the Contest is resolved
        SlotsOptionHelper.Slot slotLess;
        SlotsOptionHelper.Slot slotMore;
    }

    struct ContestFinancialData {
        uint256 totalGrossBet;
        uint256 netToShareBetweenWinners;
        SlotsOptionHelper.Fees fees;
        uint256 oddLess;
        string readableOddLess;
        uint256 oddMore;
        string readableOddMore;
    }

    error ContestIsAlreadyOpen(uint256 lastOpenContestID);
    error ContestNotOpen();
    error ContestNotClose();
    error ContestNotRefundable();
    error ContestNotResolved();
    error UserNoNeedRefund();
    error UserNoNeedSettlement();
    error BettingPeriodExpired(uint256 actualTimestamp, uint256 closeAt);
    error ContestNotMature(uint256 actualTimestamp, uint256 maturityAt);
    error InsufficientBetAmount(uint256 amountBet, uint256 minBet);
    error InsufficientBalance(uint256 userBalance, uint256 amountBet);
    error InsufficientAllowance(uint256 contractAllowance, uint256 amountBet);
    error InsufficientAmountInSlots(uint256 amountInSlotLess, uint256 amountInSlotMore, uint256 minRequired);

    modifier isCreateable() {
        if (
            _contests[LAST_OPEN_CONTEST_ID].contestStatus == SlotsOptionHelper.ContestStatus.OPEN
                && block.timestamp < _contests[LAST_OPEN_CONTEST_ID].closeAt
        ) {
            revert ContestIsAlreadyOpen({lastOpenContestID: LAST_OPEN_CONTEST_ID});
        }
        _;
    }

    modifier isContestOpen(uint256 _contestID) {
        if (_contests[_contestID].contestStatus != SlotsOptionHelper.ContestStatus.OPEN) {
            revert ContestNotOpen();
        }
        _;
    }

    modifier isContestInBettingPeriod(uint256 _contestID) {
        if (block.timestamp >= _contests[_contestID].closeAt) {
            revert BettingPeriodExpired({actualTimestamp: block.timestamp, closeAt: _contests[_contestID].closeAt});
        }
        _;
    }

    modifier isMature(uint256 _contestID) {
        if (block.timestamp < _contests[_contestID].maturityAt) {
            revert ContestNotMature({actualTimestamp: block.timestamp, maturityAt: _contests[_contestID].maturityAt});
        }
        _;
    }

    modifier isSufficientBetAmount(uint256 _amountToBet) {
        if (_amountToBet < MIN_BET) {
            revert InsufficientBetAmount({amountBet: _amountToBet, minBet: MIN_BET});
        }
        _;
    }

    modifier isSufficientBalance(uint256 _amountToBet) {
        if (IERC20(TOKEN0).balanceOf(msg.sender) < _amountToBet) {
            revert InsufficientBalance({userBalance: IERC20(TOKEN0).balanceOf(msg.sender), amountBet: _amountToBet});
        }
        _;
    }

    modifier isSufficientAllowance(uint256 _amountToBet) {
        if (IERC20(TOKEN0).allowance(msg.sender, address(this)) < _amountToBet) {
            revert InsufficientAllowance({
                contractAllowance: IERC20(TOKEN0).allowance(msg.sender, address(this)),
                amountBet: _amountToBet
            });
        }
        _;
    }

    modifier isSufficientAmountInSlots(uint256 _amountInSlotLess, uint256 _amountInSlotMore) {
        if (_amountInSlotLess < MIN_BET || _amountInSlotMore < MIN_BET) {
            revert InsufficientAmountInSlots({
                amountInSlotLess: _amountInSlotLess,
                amountInSlotMore: _amountInSlotMore,
                minRequired: MIN_BET
            });
        }
        _;
    }

    modifier isContestClose(uint256 _contestID) {
        if (
            _contests[_contestID].contestStatus != SlotsOptionHelper.ContestStatus.RESOLVED
                && _contests[_contestID].contestStatus != SlotsOptionHelper.ContestStatus.REFUNDABLE
        ) {
            revert ContestNotClose();
        }
        _;
    }

    modifier isContestStatusRefundable(uint256 _contestID) {
        if (_contests[_contestID].contestStatus != SlotsOptionHelper.ContestStatus.REFUNDABLE) {
            revert ContestNotRefundable();
        }
        _;
    }

    modifier isUserNeedRefund(uint256 _contestID, uint256 _amountInSlotLess, uint256 _amountInSlotMore) {
        bool isLessOptionStatusCreated =
            _contests[_contestID].slotLess.options[msg.sender].optionStatus == SlotsOptionHelper.OptionStatus.CREATED;
        bool isMoreOptionStatusCreated =
            _contests[_contestID].slotMore.options[msg.sender].optionStatus == SlotsOptionHelper.OptionStatus.CREATED;
        bool isNeedRefundInLess = _amountInSlotLess > 0 && isLessOptionStatusCreated;
        bool isNeedRefundInMore = _amountInSlotMore > 0 && isMoreOptionStatusCreated;
        if (!isNeedRefundInLess && !isNeedRefundInMore) {
            revert UserNoNeedRefund();
        }
        _;
    }

    modifier isContestStatusResolved(uint256 _contestID) {
        if (_contests[_contestID].contestStatus != SlotsOptionHelper.ContestStatus.RESOLVED) {
            revert ContestNotResolved();
        }
        _;
    }

    modifier isUserNeedSettlement(uint256 _contestID, uint256 _amountInWinningOption, SlotType _winningSlotType) {
        SlotsOptionHelper.Slot storage chosenSlot = _getChosenSlot(_contestID, _winningSlotType);
        bool isOptionStatusCreated =
            chosenSlot.options[msg.sender].optionStatus == SlotsOptionHelper.OptionStatus.CREATED;
        if (!(_amountInWinningOption > 0 && isOptionStatusCreated)) {
            revert UserNoNeedSettlement();
        }
        _;
    }

    event CreateContest(uint256 indexed _contestID, address indexed _creator);
    event Bet(uint256 indexed _contestID, address indexed _from, uint256 _amountBet, SlotType _isSlotMore);
    event CloseContest(
        uint256 indexed _contestID, address indexed _resolver, SlotsOptionHelper.ContestStatus indexed _contestStatus
    );
    event SplitFees(
        uint256 indexed _contestID,
        address indexed _creator,
        address indexed _resolver,
        address _collector,
        uint256 _creatorAmount,
        uint256 _resolverAmount,
        uint256 _collectorAmount
    );
    event ClaimOption(
        uint256 indexed _contestID,
        address indexed _claimer,
        SlotType indexed _slotType,
        SlotsOptionHelper.OptionStatus _optionStatus,
        uint256 _claimed
    );

    function _setLastOpenContestID(uint256 _id) internal {
        LAST_OPEN_CONTEST_ID = _id;
    }

    function getContestStatus(uint256 _contestID) public view returns (SlotsOptionHelper.ContestStatus) {
        return _contests[_contestID].contestStatus;
    }

    function getContestStartingPrice(uint256 _contestID) external view returns (uint256) {
        return _contests[_contestID].startingPrice;
    }

    function getContestMaturityPrice(uint256 _contestID) external view returns (uint256) {
        return _contests[_contestID].maturityPrice;
    }

    function getContestCloseAtTimestamp(uint256 _contestID) external view returns (uint256) {
        return _contests[_contestID].closeAt;
    }

    function getContestMaturityAtTimestamp(uint256 _contestID) external view returns (uint256) {
        return _contests[_contestID].maturityAt;
    }

    function getContestCreator(uint256 _contestID) external view returns (address) {
        return _contests[_contestID].creator;
    }

    function getContestResolver(uint256 _contestID) external view returns (address) {
        return _contests[_contestID].resolver;
    }

    function getContestWinningSlot(uint256 _contestID) public view returns (WinningSlot) {
        return _contests[_contestID].winningSlot;
    }

    function _getChosenSlot(uint256 _contestID, SlotType _slotType)
        internal
        view
        returns (SlotsOptionHelper.Slot storage)
    {
        return _slotType == SlotType.LESS ? _contests[_contestID].slotLess : _contests[_contestID].slotMore;
    }

    function getAmountBetInSlot(uint256 _contestID, SlotType _slotType) public view returns (uint256) {
        SlotsOptionHelper.Slot storage chosenSlot = _getChosenSlot(_contestID, _slotType);
        return chosenSlot.totalAmount;
    }

    function getContestPayout(uint256 _contestID, SlotType _slotType) public view returns (uint256) {
        SlotsOptionHelper.Slot storage chosenSlot = _getChosenSlot(_contestID, _slotType);
        return chosenSlot.payout;
    }

    function getAmountBetInOption(uint256 _contestID, SlotType _slotType, address _user)
        public
        view
        returns (uint256)
    {
        SlotsOptionHelper.Slot storage chosenSlot = _getChosenSlot(_contestID, _slotType);
        return chosenSlot.options[_user].amount;
    }

    function getOptionStatus(uint256 _contestID, SlotType _slotType, address _user)
        public
        view
        returns (SlotsOptionHelper.OptionStatus)
    {
        SlotsOptionHelper.Slot storage chosenSlot = _getChosenSlot(_contestID, _slotType);
        return chosenSlot.options[_user].optionStatus;
    }

    function getContestFinancialData(uint256 _amountInSlotLess, uint256 _amountInSlotMore)
        public
        view
        isSufficientAmountInSlots(_amountInSlotLess, _amountInSlotMore)
        returns (ContestFinancialData memory)
    {
        uint256 totalGrossBet = _amountInSlotLess + _amountInSlotMore;
        SlotsOptionHelper.Fees memory fees = SlotsOptionHelper.getFeesByAmount(
            totalGrossBet,
            FEE_COLLECTOR_NUMERATOR,
            FEE_CREATOR_NUMERATOR,
            FEE_RESOLVER_NUMERATOR,
            FEE_DENOMINATOR,
            MAX_FEE_CREATOR,
            MAX_FEE_RESOLVER
        );
        uint256 totalFees = fees.collector + fees.creator + fees.resolver;
        uint256 netToShareBetweenWinners = totalGrossBet - totalFees;
        uint256 oddLess = netToShareBetweenWinners * PRECISION_FACTOR / _amountInSlotLess;
        uint256 oddMore = netToShareBetweenWinners * PRECISION_FACTOR / _amountInSlotMore;

        return ContestFinancialData({
            totalGrossBet: totalGrossBet,
            netToShareBetweenWinners: netToShareBetweenWinners,
            fees: fees,
            oddLess: oddLess,
            readableOddLess: SlotsOptionHelper.getDecimalsStringFromOdd(3, oddLess, PRECISION_FACTOR, 1000),
            oddMore: oddMore,
            readableOddMore: SlotsOptionHelper.getDecimalsStringFromOdd(3, oddMore, PRECISION_FACTOR, 1000)
        });
    }

    function isContestRefundable(uint256 _contestID, uint256 _maturityPrice) public view returns (bool) {
        bool isSlotLessAmountNotValid = getAmountBetInSlot(_contestID, SlotType.LESS) < MIN_BET;
        bool isSlotMoreAmountNotValid = getAmountBetInSlot(_contestID, SlotType.MORE) < MIN_BET;
        bool isStartingPriceEqualsMaturityPrice = _contests[_contestID].startingPrice == _maturityPrice;
        return isSlotLessAmountNotValid || isSlotMoreAmountNotValid || isStartingPriceEqualsMaturityPrice;
    }

    function createContest() external isCreateable returns (bool) {
        uint256 newContestID = LAST_OPEN_CONTEST_ID + 1;
        _contests[newContestID].contestStatus = SlotsOptionHelper.ContestStatus.OPEN;
        _contests[newContestID].startedAt = block.timestamp;
        _contests[newContestID].closeAt = block.timestamp + EPOCH;
        _contests[newContestID].maturityAt = block.timestamp + (EPOCH * 2);
        _contests[newContestID].creator = msg.sender;
        _contests[newContestID].startingPrice =
            _uniswapV3TWAP.estimateAmountOut(TOKEN1, 1 ether, SECONDS_FOR_ORACLE_TWAP);
        _setLastOpenContestID(newContestID);
        emit CreateContest(newContestID, msg.sender);
        return true;
    }

    function bet(uint256 _contestID, uint256 _amountToBet, SlotType _slotType)
        external
        isContestOpen(_contestID)
        isContestInBettingPeriod(_contestID)
        isSufficientBetAmount(_amountToBet)
        isSufficientBalance(_amountToBet)
        isSufficientAllowance(_amountToBet)
        returns (bool)
    {
        SlotsOptionHelper.Slot storage chosenSlot = _getChosenSlot(_contestID, _slotType);
        chosenSlot.totalAmount += _amountToBet;
        bool isUserFirstBet =
            getOptionStatus(_contestID, _slotType, msg.sender) == SlotsOptionHelper.OptionStatus.UNDEFINED;
        if (isUserFirstBet) chosenSlot.options[msg.sender].optionStatus = SlotsOptionHelper.OptionStatus.CREATED;
        chosenSlot.options[msg.sender].amount += _amountToBet;
        IERC20(TOKEN0).safeTransferFrom(msg.sender, address(this), _amountToBet);
        emit Bet(_contestID, msg.sender, _amountToBet, _slotType);
        return true;
    }

    function _splitFees(uint256 _contestID, SlotsOptionHelper.Fees memory _fees) internal {
        IERC20(TOKEN0).safeTransfer(_contests[_contestID].creator, _fees.creator);
        IERC20(TOKEN0).safeTransfer(_contests[_contestID].resolver, _fees.resolver);
        IERC20(TOKEN0).safeTransfer(FEES_COLLECTOR, _fees.collector);
        emit SplitFees(
            _contestID,
            _contests[_contestID].creator,
            _contests[_contestID].resolver,
            FEES_COLLECTOR,
            _fees.creator,
            _fees.resolver,
            _fees.collector
            );
    }

    function mockCloseContest(uint256 _contestID, uint256 _fakeMaturityPrice, bool _isMoreWin)
        external
        isContestOpen(_contestID)
        isMature(_contestID)
        returns (bool)
    {
        uint256 maturityPrice = _isMoreWin
            ? _uniswapV3TWAP.estimateAmountOut(TOKEN1, 1 ether, SECONDS_FOR_ORACLE_TWAP) + _fakeMaturityPrice
            : _uniswapV3TWAP.estimateAmountOut(TOKEN1, 1 ether, SECONDS_FOR_ORACLE_TWAP) - _fakeMaturityPrice;
        bool isRefundable = isContestRefundable(_contestID, maturityPrice);
        _contests[_contestID].maturityPrice = maturityPrice;
        if (isRefundable) {
            _contests[_contestID].contestStatus = SlotsOptionHelper.ContestStatus.REFUNDABLE;
        } else {
            _contests[_contestID].contestStatus = SlotsOptionHelper.ContestStatus.RESOLVED;
            ContestFinancialData memory contestFinancialData = getContestFinancialData(
                _contests[_contestID].slotLess.totalAmount, _contests[_contestID].slotMore.totalAmount
            );
            _contests[_contestID].resolver = msg.sender;
            _contests[_contestID].winningSlot =
                maturityPrice > _contests[_contestID].startingPrice ? WinningSlot.MORE : WinningSlot.LESS;
            _contests[_contestID].slotLess.payout = contestFinancialData.oddLess;
            _contests[_contestID].slotMore.payout = contestFinancialData.oddMore;
            _splitFees(_contestID, contestFinancialData.fees);
        }
        emit CloseContest(
            _contestID,
            msg.sender,
            isRefundable ? SlotsOptionHelper.ContestStatus.REFUNDABLE : SlotsOptionHelper.ContestStatus.RESOLVED
            );
        return true;
    }

    function _askRefund(uint256 _contestID, uint256 _amountInOptionLess, uint256 _amountInOptionMore)
        internal
        isUserNeedRefund(_contestID, _amountInOptionLess, _amountInOptionMore)
        returns (uint256)
    {
        uint256 amountToRefund;
        if (_amountInOptionLess > 0) {
            amountToRefund += _amountInOptionLess;
            _contests[_contestID].slotLess.options[msg.sender].optionStatus = SlotsOptionHelper.OptionStatus.REFUNDED;
            emit ClaimOption(
                _contestID, msg.sender, SlotType.LESS, SlotsOptionHelper.OptionStatus.REFUNDED, _amountInOptionLess
                );
        }
        if (_amountInOptionMore > 0) {
            amountToRefund += _amountInOptionMore;
            _contests[_contestID].slotMore.options[msg.sender].optionStatus = SlotsOptionHelper.OptionStatus.REFUNDED;
            emit ClaimOption(
                _contestID, msg.sender, SlotType.MORE, SlotsOptionHelper.OptionStatus.REFUNDED, _amountInOptionMore
                );
        }
        return amountToRefund;
    }

    function _askSettlement(uint256 _contestID, uint256 _amountInWinningOption, SlotType _winningSlot)
        internal
        isUserNeedSettlement(_contestID, _amountInWinningOption, _winningSlot)
        returns (uint256)
    {
        uint256 amountToSettle = SlotsOptionHelper.getAmountToPayoutIfResolved(
            _amountInWinningOption, getContestPayout(_contestID, _winningSlot), PRECISION_FACTOR
        );
        SlotsOptionHelper.Slot storage chosenSlot = _getChosenSlot(_contestID, _winningSlot);
        chosenSlot.options[msg.sender].optionStatus = SlotsOptionHelper.OptionStatus.SETTLED;
        emit ClaimOption(_contestID, msg.sender, _winningSlot, SlotsOptionHelper.OptionStatus.SETTLED, amountToSettle);
        return amountToSettle;
    }

    function claimRefund(uint256 _contestID)
        external
        isContestClose(_contestID)
        isContestStatusRefundable(_contestID)
        returns (bool)
    {
        uint256 amountInOptionLess = getAmountBetInOption(_contestID, SlotType.LESS, msg.sender);
        uint256 amountInOptionMore = getAmountBetInOption(_contestID, SlotType.MORE, msg.sender);
        uint256 amountToClaim = _askRefund(_contestID, amountInOptionLess, amountInOptionMore);
        IERC20(TOKEN0).safeTransfer(msg.sender, amountToClaim);
        return true;
    }

    function claimSettlement(uint256 _contestID)
        external
        isContestClose(_contestID)
        isContestStatusResolved(_contestID)
        returns (bool)
    {
        WinningSlot winningSlot = getContestWinningSlot(_contestID);
        SlotType winningSlotType = winningSlot == WinningSlot.LESS ? SlotType.LESS : SlotType.MORE;
        uint256 amountInWinningOption = getAmountBetInOption(_contestID, winningSlotType, msg.sender);
        uint256 amountToClaim = _askSettlement(_contestID, amountInWinningOption, winningSlotType);
        IERC20(TOKEN0).safeTransfer(msg.sender, amountToClaim);
        return true;
    }
}
