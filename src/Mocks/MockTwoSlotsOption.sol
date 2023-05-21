// SPDX-License-Identifier: CC-BY-NC-ND-4.0 (Creative Commons Attribution Non Commercial No Derivatives 4.0 International)
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SlotsOptionHelper} from "../Libraries/SlotsOptionHelper.sol";
import {UniswapV3TWAP} from "../UniswapV3TWAP.sol";

/// @title TwoSlotsOption
/// @author @fr0xMaster
/// @notice MOCK VERSION of Mutual Slots implementation of Two Slots Option contract To Help Testing Logic without integration limitations.

contract MockTwoSlotsOption is Ownable {
    using SafeERC20 for IERC20;

    address public FEES_COLLECTOR; // address who receives fees generated by contract activity
    address public immutable FACTORY; // address of UNISWAP V3 FACTORY.
    address public immutable TOKEN0; // address of USDC Token
    address public immutable TOKEN1; // address of ERC20 Token use for Options (ex. ETH, ARB, WBTC,...)
    uint24 public UNISWAP_POOL_FEE; // fees of the desired Uniswap pool in order to use the V3 oracle features
    uint8 public SECONDS_FOR_ORACLE_TWAP; // fees of the desired Uniswap pool in order to use the V3 oracle features
    UniswapV3TWAP uniswapV3TWAP;
    uint256 public MIN_BET; // minimum amount to bet - to avoid spam attack & underflow
    uint256 public MAX_BET_IN_SLOT; // maximum amount Bet in Slot to allow a precise redistribution of the gains
    uint256 public PRECISION_FACTOR; // used to allow for better accuracy of odds and redistribution of winnings
    uint8 public FEE_NUMERATOR; // numerator to calculate fees
    uint8 public FEE_DENOMINATOR; // denominator to calculate fees
    uint256 public EPOCH; // duration of an epoch expressed in seconds
    uint256 public LAST_OPEN_CONTEST_ID; // ID of last contest open.
    mapping(uint256 => Contest) contests; // mapping of all contests formatted as struct.

    constructor(
        address _FEES_COLLECTOR,
        address _FACTORY,
        address _TOKEN0,
        address _TOKEN1,
        uint24 _UNISWAP_POOL_FEE,
        uint8 _SECONDS_FOR_ORACLE_TWAP,
        uint8 _FEE_NUMERATOR,
        uint8 _FEE_DENOMINATOR,
        uint256 _MIN_BET,
        uint256 _MAX_BET_IN_SLOT,
        uint256 _PRECISION_FACTOR,
        uint256 _EPOCH
    ) {
        FEES_COLLECTOR = _FEES_COLLECTOR;
        FACTORY = _FACTORY;
        TOKEN0 = _TOKEN0;
        TOKEN1 = _TOKEN1;
        UNISWAP_POOL_FEE = _UNISWAP_POOL_FEE;
        SECONDS_FOR_ORACLE_TWAP = _SECONDS_FOR_ORACLE_TWAP;
        FEE_NUMERATOR = _FEE_NUMERATOR;
        FEE_DENOMINATOR = _FEE_DENOMINATOR;
        MIN_BET = _MIN_BET;
        MAX_BET_IN_SLOT = _MAX_BET_IN_SLOT;
        PRECISION_FACTOR = _PRECISION_FACTOR;
        EPOCH = _EPOCH;
        uniswapV3TWAP = new UniswapV3TWAP(FACTORY, TOKEN0,TOKEN1,UNISWAP_POOL_FEE);
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

    struct Odds {
        uint256 oddLess;
        string readableOddLess;
        uint256 oddMore;
        string readableOddMore;
    }

    error ContestIsAlreadyOpen(uint256 lastOpenContestID);
    error ContestNotOpen();
    error BettingPeriodExpired(uint256 actualTimestamp, uint256 closeAt);
    error ContestNotMature(uint256 actualTimestamp, uint256 maturityAt);
    error InsufficientBetAmount(uint256 amountBet, uint256 minBet);
    error InsufficientBalance(uint256 userBalance, uint256 amountBet);
    error InsufficientAllowance(uint256 contractAllowance, uint256 amountBet);
    error InsufficientAmountInSlots(uint256 amountInSlotLess, uint256 amountInSlotMore, uint256 minRequired);
    error MaxAmountInSlotReached(uint256 amountBet, SlotType slot, uint256 maxBetRemaining);

    modifier isCreateable() {
        if (
            contests[LAST_OPEN_CONTEST_ID].contestStatus == SlotsOptionHelper.ContestStatus.OPEN
                && block.timestamp < contests[LAST_OPEN_CONTEST_ID].closeAt
        ) {
            revert ContestIsAlreadyOpen({lastOpenContestID: LAST_OPEN_CONTEST_ID});
        }
        _;
    }

    modifier isContestOpen(uint256 _contestID) {
        if (contests[_contestID].contestStatus != SlotsOptionHelper.ContestStatus.OPEN) {
            revert ContestNotOpen();
        }
        _;
    }

    modifier isContestInBettingPeriod(uint256 _contestID) {
        if (block.timestamp >= contests[_contestID].closeAt) {
            revert BettingPeriodExpired({actualTimestamp: block.timestamp, closeAt: contests[_contestID].closeAt});
        }
        _;
    }

    modifier isMature(uint256 _contestID) {
        if (block.timestamp < contests[_contestID].maturityAt) {
            revert ContestNotMature({actualTimestamp: block.timestamp, maturityAt: contests[_contestID].maturityAt});
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

    modifier isMaxAmountNotReached(uint256 _contestID, uint256 _amountToBet, SlotType _slotType) {
        if (getAmountBetInSlot(_contestID, _slotType) + _amountToBet > MAX_BET_IN_SLOT) {
            uint256 maxBetRemaining = MAX_BET_IN_SLOT - getAmountBetInSlot(_contestID, _slotType);
            revert MaxAmountInSlotReached({amountBet: _amountToBet, slot: _slotType, maxBetRemaining: maxBetRemaining});
        }
        _;
    }

    event CreateContest(uint256 indexed _contestID, address indexed _creator);
    event Bet(uint256 indexed _contestID, address indexed _from, uint256 _amountBet, SlotType _isSlotMore);
    event CloseContest(
        uint256 indexed _contestID, address indexed _resolver, SlotsOptionHelper.ContestStatus indexed _contestStatus
    );

    function setLastOpenContestID(uint256 _id) internal {
        LAST_OPEN_CONTEST_ID = _id;
    }

    function getContestStatus(uint256 _contestID) external view returns (SlotsOptionHelper.ContestStatus) {
        return contests[_contestID].contestStatus;
    }

    function getContestStartingPrice(uint256 _contestID) public view returns (uint256) {
        return contests[_contestID].startingPrice;
    }

    function getContestMaturityPrice(uint256 _contestID) external view returns (uint256) {
        return contests[_contestID].maturityPrice;
    }

    function getContestCloseAtTimestamp(uint256 _contestID) external view returns (uint256) {
        return contests[_contestID].closeAt;
    }

    function getContestMaturityAtTimestamp(uint256 _contestID) external view returns (uint256) {
        return contests[_contestID].maturityAt;
    }

    function getContestCreator(uint256 _contestID) external view returns (address) {
        return contests[_contestID].creator;
    }

    function getContestResolver(uint256 _contestID) external view returns (address) {
        return contests[_contestID].resolver;
    }

    function getContestWinningSlot(uint256 _contestID) external view returns (WinningSlot) {
        return contests[_contestID].winningSlot;
    }

    function getChosenSlot(uint256 _contestID, SlotType _slotType)
        internal
        view
        returns (SlotsOptionHelper.Slot storage)
    {
        return _slotType == SlotType.LESS ? contests[_contestID].slotLess : contests[_contestID].slotMore;
    }

    function getAmountBetInSlot(uint256 _contestID, SlotType _slotType) public view returns (uint256) {
        SlotsOptionHelper.Slot storage chosenSlot = getChosenSlot(_contestID, _slotType);
        return chosenSlot.totalAmount;
    }

    function getContestOdd(uint256 _contestID, SlotType _slotType) external view returns (uint256) {
        SlotsOptionHelper.Slot storage chosenSlot = getChosenSlot(_contestID, _slotType);
        return chosenSlot.odd;
    }

    function getAmountBetInOption(uint256 _contestID, SlotType _slotType, address _user)
        external
        view
        returns (uint256)
    {
        SlotsOptionHelper.Slot storage chosenSlot = getChosenSlot(_contestID, _slotType);
        return chosenSlot.options[_user].amount;
    }

    function getOptionStatus(uint256 _contestID, SlotType _slotType, address _user)
        public
        view
        returns (SlotsOptionHelper.OptionStatus)
    {
        SlotsOptionHelper.Slot storage chosenSlot = getChosenSlot(_contestID, _slotType);
        return chosenSlot.options[_user].optionStatus;
    }

    function getContestFinancialData(uint256 _amountInSlotLess, uint256 _amountInSlotMore)
        public
        view
        returns (SlotsOptionHelper.ContestFinancialData memory)
    {
        uint256 totalGrossBet = _amountInSlotLess + _amountInSlotMore;
        uint256 fees = SlotsOptionHelper.getFeeByAmount(totalGrossBet, FEE_NUMERATOR, FEE_DENOMINATOR);
        uint256 netToShareBetweenWinners = totalGrossBet - fees;
        return SlotsOptionHelper.ContestFinancialData({
            totalGrossBet: totalGrossBet,
            fees: fees,
            netToShareBetweenWinners: netToShareBetweenWinners
        });
    }

    function getOdds(uint256 _amountInSlotLess, uint256 _amountInSlotMore)
        public
        view
        isSufficientAmountInSlots(_amountInSlotLess, _amountInSlotMore)
        returns (Odds memory)
    {
        SlotsOptionHelper.ContestFinancialData memory contestFinancialData =
            getContestFinancialData(_amountInSlotLess, _amountInSlotMore);
        uint256 oddLess = contestFinancialData.netToShareBetweenWinners * PRECISION_FACTOR / _amountInSlotLess;
        string memory readableOddLess = SlotsOptionHelper.getDecimalsStringFromOdd(3, oddLess, PRECISION_FACTOR, 1000);
        uint256 oddMore = contestFinancialData.netToShareBetweenWinners * PRECISION_FACTOR / _amountInSlotMore;
        string memory readableOddMore = SlotsOptionHelper.getDecimalsStringFromOdd(3, oddMore, PRECISION_FACTOR, 1000);

        return Odds({
            oddLess: oddLess,
            readableOddLess: readableOddLess,
            oddMore: oddMore,
            readableOddMore: readableOddMore
        });
    }

    function isContestRefundable(uint256 _contestID, uint256 _maturityPrice) public view returns (bool) {
        bool isSlotLessAmountNotValid = getAmountBetInSlot(_contestID, SlotType.LESS) < MIN_BET;
        bool isSlotMoreAmountNotValid = getAmountBetInSlot(_contestID, SlotType.MORE) < MIN_BET;
        bool isStartingPriceEqualsMaturityPrice = contests[_contestID].startingPrice == _maturityPrice;

        return isSlotLessAmountNotValid || isSlotMoreAmountNotValid || isStartingPriceEqualsMaturityPrice;
    }

    function createContest() external isCreateable returns (bool) {
        uint256 newContestID = LAST_OPEN_CONTEST_ID + 1;
        contests[newContestID].contestStatus = SlotsOptionHelper.ContestStatus.OPEN;
        contests[newContestID].startedAt = block.timestamp;
        contests[newContestID].closeAt = block.timestamp + EPOCH;
        contests[newContestID].maturityAt = block.timestamp + (EPOCH * 2);
        contests[newContestID].creator = msg.sender;
        contests[newContestID].startingPrice = uniswapV3TWAP.estimateAmountOut(TOKEN1, 1 ether, SECONDS_FOR_ORACLE_TWAP);
        setLastOpenContestID(newContestID);
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
        isMaxAmountNotReached(_contestID, _amountToBet, _slotType)
        returns (bool)
    {
        SlotsOptionHelper.Slot storage chosenSlot = getChosenSlot(_contestID, _slotType);
        chosenSlot.totalAmount += _amountToBet;
        bool isUserFirstBet =
            getOptionStatus(_contestID, _slotType, msg.sender) == SlotsOptionHelper.OptionStatus.UNDEFINED;
        if (isUserFirstBet) chosenSlot.options[msg.sender].optionStatus = SlotsOptionHelper.OptionStatus.CREATED;
        chosenSlot.options[msg.sender].amount += _amountToBet;
        IERC20(TOKEN0).safeTransferFrom(msg.sender, address(this), _amountToBet);
        emit Bet(_contestID, msg.sender, _amountToBet, _slotType);
        return true;
    }

    function mockCloseContest(uint256 _contestID, uint256 _fakeMaturityPrice, bool _isMoreWin)
        external
        isContestOpen(_contestID)
        isMature(_contestID)
        returns (bool)
    {
        uint256 uniswapPrice = uniswapV3TWAP.estimateAmountOut(TOKEN1, 1 ether, SECONDS_FOR_ORACLE_TWAP);
        uint256 maturityPrice = _isMoreWin ? uniswapPrice + _fakeMaturityPrice : uniswapPrice - _fakeMaturityPrice;
        contests[_contestID].maturityPrice = maturityPrice;
        contests[_contestID].resolver = msg.sender;
        bool isRefundable = isContestRefundable(_contestID, maturityPrice);

        if (isRefundable) {
            contests[_contestID].contestStatus = SlotsOptionHelper.ContestStatus.REFUNDABLE;
            emit CloseContest(_contestID, msg.sender, SlotsOptionHelper.ContestStatus.REFUNDABLE);
        } else {
            contests[_contestID].contestStatus = SlotsOptionHelper.ContestStatus.RESOLVED;
            uint256 amountInSlotLess = getAmountBetInSlot(_contestID, SlotType.LESS);
            uint256 amountInSlotMore = getAmountBetInSlot(_contestID, SlotType.MORE);
            Odds memory odds = getOdds(amountInSlotLess, amountInSlotMore);
            contests[_contestID].slotLess.odd = odds.oddLess;
            contests[_contestID].slotMore.odd = odds.oddMore;
            uint256 startingPrice = getContestStartingPrice(_contestID);
            contests[_contestID].winningSlot = maturityPrice > startingPrice ? WinningSlot.MORE : WinningSlot.LESS;
            emit CloseContest(_contestID, msg.sender, SlotsOptionHelper.ContestStatus.RESOLVED);
        }

        return true;
    }
}