// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable2Step, Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {ChainlinkClient} from "@chainlink-contracts-1.3.0/v0.8/ChainlinkClient.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink-contracts-1.3.0/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink-contracts-1.3.0/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink-contracts-1.3.0/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {LinkTokenInterface} from "@chainlink-contracts-1.3.0/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract Lottery is Ownable2Step, VRFV2PlusWrapperConsumerBase {
    error InsufficientBalance();
    error NotOpen();
    error AmountZero();
    error LotteryActive();
    error NotTheWinner();

    IERC20 public immutable token;
    address public winner;

    uint256 public ticketCounter;
    uint256 public saleStartTime;
    uint256 public saleEndTime;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    uint256[] public requestIds;
    uint256 public lastRequestId;

    mapping(address => uint256[]) public ticketNumber;
    mapping(uint256 => address) public ticketOwner;
    mapping(uint256 => RequestStatus) public s_requests;

    enum LotteryState {
        TicketSaleOpen,
        LotteryClosed,
        CalculatingWinner
    }

    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256[] randomWords;
    }

    LotteryState public currentState;

    constructor(
        address _tokenAddress,
        uint256 _saleStartTime,
        uint256 _saleEndTime,
        address _vrfV2PlusWrapper
    ) VRFV2PlusWrapperConsumerBase(_vrfV2PlusWrapper) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
        currentState = LotteryState.TicketSaleOpen;
        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
    }

    function requestRandomWords(
        bool enableNativePayment
    ) external onlyOwner returns (uint256) {
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment})
        );
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
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;

        return requestId;
    }

    function updateState() public {
        if (
            block.timestamp >= saleStartTime && block.timestamp <= saleEndTime
        ) {
            currentState = LotteryState.TicketSaleOpen;
        } else {
            currentState = LotteryState.LotteryClosed;
        }
    }

    function supplyToken(
        address _user,
        uint256 _amount
    ) external returns (uint256) {
        updateState();
        if (token.balanceOf(_user) < _amount) revert InsufficientBalance();
        if (currentState != LotteryState.TicketSaleOpen) revert NotOpen();
        if (_amount == 0) revert AmountZero();
        currentState = LotteryState.TicketSaleOpen;

        token.transferFrom(msg.sender, address(this), _amount);

        uint256 ticketsToIssue = _amount / 100;

        for (uint256 i = 0; i < ticketsToIssue; i++) {
            ticketNumber[msg.sender].push(ticketCounter);
            ticketOwner[ticketCounter] = msg.sender;
            ticketCounter++;
        }
        return ticketCounter;
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
        uint256 /* _requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 winningTicket = (randomWords[0] % ticketCounter);

        winner = ticketOwner[winningTicket];
    }

    function withdrawWinnings() external {
        updateState();
        if (currentState != LotteryState.LotteryClosed) revert LotteryActive();
        if (msg.sender != winner) revert NotTheWinner();

        token.transferFrom(
            address(this),
            msg.sender,
            token.balanceOf(address(this))
        );
    }
    function getTicketCount(address _user) external view returns (uint256) {
        return ticketNumber[_user].length;
    }

    function getTicketBalance(
        address _user
    ) external view returns (uint256[] memory) {
        return ticketNumber[_user];
    }

    function hasTicket(
        address _user,
        uint256 _ticketNumber
    ) external view returns (bool) {
        return ticketOwner[_ticketNumber] == _user;
    }

    function checkLotteryNr() external view returns (uint256) {
        return ticketCounter;
    }
}
