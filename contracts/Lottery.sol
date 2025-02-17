// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// ownable2Step and erc-20/Ierc20;
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Lottery is Ownable2Step {
    error InsufficientBalance();
    error NotOpen();
    error AmountZero();

    // constructor that inizializes a token or maybe not so many tokens could be used
    // constructor ownable2 step

    IERC20 public immutable token;
    uint256 public ticketCounter;
    uint256 public saleStartTime;
    uint256 public saleEndTime;

    mapping(address => uint256[]) public ticketNumber;
    mapping(uint256 => address) public ticketOwner;

    enum LotteryState {
        TicketSaleOpen,
        LotteryClosed,
        CalculatingWinner
    }

    LotteryState public currentState;

    constructor(
        address _tokenAddress,
        uint256 _saleStartTime,
        uint256 _saleEndTime
    ) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
        currentState = LotteryState.TicketSaleOpen;
        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
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

    function supplyToken(address _user, uint256 _amount) external {
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
    }

    function withdrawWinnings() external onlyOwner {}

    function checkLotteryNr() external view returns (uint256) {}
}
