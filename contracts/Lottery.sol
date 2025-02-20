// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// ownable2Step and erc-20/Ierc20;
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink-contracts-1.3.0/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink-contracts-1.3.0/vrf/dev/libraries/VRFV2PlusClient.sol";
import {LinkTokenInterface} from "@chainlink-contracts-1.3.0/shared/interfaces/LinkTokenInterface.sol";

contract Lottery is Ownable2Step, VRFV2PlusWrapperConsumerBase {
    error InsufficientBalance();
    error NotOpen();
    error AmountZero();
    error LotteryActive();
    error NotTheWinner();

    // constructor that inizializes a token or maybe not so many tokens could be used
    // constructor ownable2 step

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
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */

    enum LotteryState {
        TicketSaleOpen,
        LotteryClosed,
        CalculatingWinner
    }

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
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

    // functions

    function updateState() internal {
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

        // Issue tickets by updating mappings.
        for (uint256 i = 0; i < ticketsToIssue; i++) {
            ticketCounter++; // Generate a new unique ticket number.
            ticketNumber[msg.sender].push(ticketCounter); // Add the ticket to the user's list.
            ticketOwner[ticketCounter] = msg.sender; // Map the ticket number to the user.
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
        uint256 winningTicket = (randomWords[0] % ticketCounter) + 1;

        winner = ticketOwner[winningTicket];
    }

    function withdrawWinnings() external onlyOwner {
        updateState();
        if (currentState != LotteryState.LotteryClosed) revert LotteryActive();
        if (msg.sender != winner) revert NotTheWinner();
        // calculate the winnigs.
        // make sure the user is the one with the winning ticket
        // transfer funds that are in the contract.
        token.transferFrom(
            address(this),
            msg.sender,
            token.balanceOf(address(this))
        );
        // double check if this function has to be only owner.
        // variable of the winning nr.
    }

    // let' users check how many ticket they have.
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
