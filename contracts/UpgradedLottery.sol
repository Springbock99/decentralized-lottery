// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable2Step, Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink-contracts-1.3.0/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink-contracts-1.3.0/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract UpgradedLottery is Ownable2Step, VRFV2PlusWrapperConsumerBase {
    error InsufficientBalance();
    error NotOpen();
    error AmountZero();
    error LotteryActive();
    error NotTheWinner();
    error RoundNotFinished();
    error NoTicketsSold();
    error InvalidSalePeriod();

    IERC20 public immutable token;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    struct Round {
        uint256 saleStartTime;
        uint256 saleEndTime;
        uint256 ticketCounter;
        address winner;
        uint256 prizePool;
        bool finished;
        mapping(uint256 => address) ticketOwner;
        mapping(address => uint256[]) ticketNumber;
    }

    mapping(uint256 => Round) public rounds;
    uint256 public currentRoundId;
    mapping(uint256 => RequestStatus) public s_requests;
    uint256[] public requestIds;
    uint256 public lastRequestId;

    enum LotteryState {
        TicketSaleOpen,
        LotteryClosed,
        CalculatingWinner
    }

    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256[] randomWords;
        uint256 roundId;
    }

    LotteryState public currentState;

    constructor(
        address _tokenAddress,
        uint256 _saleStartTime,
        uint256 _saleEndTime,
        address _vrfV2PlusWrapper
    ) VRFV2PlusWrapperConsumerBase(_vrfV2PlusWrapper) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
        currentRoundId = 1;
        rounds[currentRoundId].saleStartTime = _saleStartTime;
        rounds[currentRoundId].saleEndTime = _saleEndTime;
        if (_saleEndTime <= _saleStartTime) revert InvalidSalePeriod();
        currentState = LotteryState.TicketSaleOpen;
    }

    function startNewRound(
        uint256 _saleStartTime,
        uint256 _saleEndTime
    ) external onlyOwner {
        Round storage currentRound = rounds[currentRoundId];
        if (!currentRound.finished && currentRound.ticketCounter > 0) {
            revert RoundNotFinished();
        }
        if (_saleEndTime <= _saleStartTime) revert InvalidSalePeriod();

        currentRoundId++;
        Round storage newRound = rounds[currentRoundId];
        newRound.saleStartTime = _saleStartTime;
        newRound.saleEndTime = _saleEndTime;
        currentState = LotteryState.TicketSaleOpen;
    }

    function requestRandomWords(
        bool enableNativePayment
    ) external onlyOwner returns (uint256) {
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment})
        );
        updateState();
        if (currentState != LotteryState.LotteryClosed) revert LotteryActive();
        if (rounds[currentRoundId].ticketCounter == 0) revert NoTicketsSold();

        uint256 requestId;
        uint256 reqPrice;
        if (enableNativePayment) {
            (requestId, reqPrice) = requestRandomnessPayInNative(
                callbackGasLimit,
                requestConfirmations,
                numWords,
                extraArgs
            );
        } else {
            (requestId, reqPrice) = requestRandomness(
                callbackGasLimit,
                requestConfirmations,
                numWords,
                extraArgs
            );
        }
        s_requests[requestId] = RequestStatus({
            paid: reqPrice,
            randomWords: new uint256[](0),
            fulfilled: false,
            roundId: currentRoundId
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        currentState = LotteryState.CalculatingWinner;
        return requestId;
    }

    function updateState() public {
        Round storage round = rounds[currentRoundId];
        if (
            block.timestamp >= round.saleStartTime &&
            block.timestamp <= round.saleEndTime
        ) {
            currentState = LotteryState.TicketSaleOpen;
        } else if (!round.finished) {
            currentState = LotteryState.LotteryClosed;
        }
    }

    function supplyToken(
        address _user,
        uint256 _amount
    ) external returns (uint256) {
        updateState();
        Round storage round = rounds[currentRoundId];
        if (token.balanceOf(_user) < _amount) revert InsufficientBalance();
        if (currentState != LotteryState.TicketSaleOpen) revert NotOpen();
        if (_amount == 0) revert AmountZero();

        token.transferFrom(msg.sender, address(this), _amount);
        round.prizePool += _amount;

        uint256 ticketsToIssue = _amount / 100;
        for (uint256 i = 0; i < ticketsToIssue; i++) {
            round.ticketNumber[msg.sender].push(round.ticketCounter);
            round.ticketOwner[round.ticketCounter] = msg.sender;
            round.ticketCounter++;
        }
        return round.ticketCounter;
    }

    function pickWinner() external onlyOwner {
        bytes memory extra;
        updateState();
        if (currentState != LotteryState.LotteryClosed) revert LotteryActive();
        requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords,
            extra
        );
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory randomWords
    ) internal override {
        RequestStatus storage request = s_requests[_requestId];
        require(!request.fulfilled, "Request already fulfilled");
        require(request.roundId == currentRoundId, "Invalid round");

        Round storage round = rounds[currentRoundId];
        uint256 winningTicket = randomWords[0] % round.ticketCounter;
        round.winner = round.ticketOwner[winningTicket];

        request.fulfilled = true;
        request.randomWords = randomWords;
        round.finished = true;
        currentState = LotteryState.LotteryClosed;
    }

    function withdrawWinnings() external {
        Round storage round = rounds[currentRoundId];
        updateState();
        if (currentState != LotteryState.LotteryClosed) revert LotteryActive();
        if (!round.finished) revert RoundNotFinished();
        if (msg.sender != round.winner) revert NotTheWinner();

        uint256 prize = round.prizePool;
        round.prizePool = 0;
        token.transfer(msg.sender, prize);
    }

    function getTicketCount(
        uint256 roundId,
        address _user
    ) external view returns (uint256) {
        return rounds[roundId].ticketNumber[_user].length;
    }

    function getTicketBalance(
        uint256 roundId,
        address _user
    ) external view returns (uint256[] memory) {
        return rounds[roundId].ticketNumber[_user];
    }

    function hasTicket(
        uint256 roundId,
        address _user,
        uint256 _ticketNumber
    ) external view returns (bool) {
        return rounds[roundId].ticketOwner[_ticketNumber] == _user;
    }

    function checkLotteryNr(uint256 roundId) external view returns (uint256) {
        return rounds[roundId].ticketCounter;
    }

    function getRoundInfo(
        uint256 roundId
    )
        external
        view
        returns (
            uint256 saleStartTime,
            uint256 saleEndTime,
            uint256 ticketCounter,
            address winner,
            uint256 prizePool,
            bool finished
        )
    {
        Round storage round = rounds[roundId];
        return (
            round.saleStartTime,
            round.saleEndTime,
            round.ticketCounter,
            round.winner,
            round.prizePool,
            round.finished
        );
    }
}
