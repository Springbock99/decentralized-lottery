// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {UpgradedLottery} from "../contracts/UpgradedLottery.sol";
import {Ownable2Step, Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {VRFV2PlusClient} from "@chainlink-contracts-1.3.0/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract UpgradedLotteryTest is Test {
    UpgradedLottery public lottery;

    string ALCHEMY_URL;

    address public owner;
    address public user1;
    address public user2;

    address chainLinkToken = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address chainLinkVRFWrapper = 0x02aae1A04f9828517b3007f83f6181900CaD910c;
    IERC20 link = IERC20(chainLinkToken);

    uint256 public constant TICKET_PRICE = 100;
    uint256 public constant INITIAL_BALANCE = 1000 * TICKET_PRICE;

    uint256 requestId = 1;
    address VRFCoordinator;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        ALCHEMY_URL = vm.envOr(
            "ALCHEMY_URL",
            string(
                "https://eth-mainnet.g.alchemy.com/v2/zNMGaVTfo_oc5Wngx6AQHIKUhcTXsCJD"
            )
        );

        vm.createSelectFork(ALCHEMY_URL);

        vm.startPrank(owner);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        lottery = new UpgradedLottery(
            address(chainLinkToken),
            startTime,
            endTime,
            address(chainLinkVRFWrapper)
        );

        VRFCoordinator = address(chainLinkVRFWrapper);

        deal(address(link), user1, 1 ether);
        deal(address(link), user2, 1 ether);

        deal(address(link), address(lottery), 10 ether);

        vm.stopPrank();

        vm.startPrank(user1);
        link.approve(address(lottery), 1 ether);
        console.log(
            "Allowance for Lottery:",
            link.allowance(user1, address(lottery))
        );
        vm.stopPrank();

        vm.startPrank(user2);
        link.approve(address(lottery), 1 ether);
        console.log(
            "Allowance for Lottery:",
            link.allowance(user2, address(lottery))
        );
        vm.stopPrank();
    }

    function test_InitialState() public {
        assertEq(
            uint256(lottery.currentState()),
            uint256(UpgradedLottery.LotteryState.TicketSaleOpen)
        );
        assertEq(lottery.currentRoundId(), 1);

        (
            uint256 saleStartTime,
            uint256 saleEndTime,
            uint256 ticketCounter,
            address winner,
            uint256 prizePool,
            bool finished
        ) = lottery.getRoundInfo(1);

        assertEq(ticketCounter, 0);
        assertEq(winner, address(0));
        assertEq(prizePool, 0);
        assertEq(finished, false);
    }

    function test_GetTicketCount() public {
        console.log("User1 LINK balance:", link.balanceOf(user1));
        console.log(
            "Allowance before supply:",
            link.allowance(user1, address(lottery))
        );

        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        uint256[] memory tickets = lottery.getTicketBalance(1, user1);
        assertEq(tickets.length, 3);
        assertEq(tickets[0], 0);
        assertEq(tickets[1], 1);
        assertEq(tickets[2], 2);

        assertEq(lottery.getTicketCount(1, user1), 3);
        assertEq(lottery.checkLotteryNr(1), 3);
    }

    function test_FailSupplyTokenInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.InsufficientBalance.selector)
        );
        lottery.supplyToken(user1, 2 ether);
    }

    function test_Supply0Tokens() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.AmountZero.selector)
        );
        lottery.supplyToken(user1, 0);
    }

    function test_FailSupplyWhenTicketClosed() public {
        vm.warp(block.timestamp + 1 days + 1);
        lottery.updateState();

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.NotOpen.selector)
        );
        lottery.supplyToken(user1, 300);
    }

    function test_MultipleUsersBuyTickets() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.prank(user2);
        lottery.supplyToken(user2, 500);

        assertEq(lottery.getTicketCount(1, user1), 3);
        assertEq(lottery.getTicketCount(1, user2), 5);
        (, , uint256 ticketCounter, , , ) = lottery.getRoundInfo(1);
        assertEq(ticketCounter, 8);

        uint256 lotteryBalance = link.balanceOf(address(lottery));
        assertGt(lotteryBalance, 800);
    }

    function test_HasTicket() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.prank(user2);
        lottery.supplyToken(user2, 500);

        assertTrue(lottery.hasTicket(1, user1, 0));
        assertTrue(lottery.hasTicket(1, user1, 1));
        assertTrue(lottery.hasTicket(1, user1, 2));

        assertTrue(lottery.hasTicket(1, user2, 3));
        assertTrue(lottery.hasTicket(1, user2, 7));

        assertFalse(lottery.hasTicket(1, user1, 3));
        assertFalse(lottery.hasTicket(1, user2, 0));
    }

    function test_RequestRandomWordsOnlyOwner() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.updateState();

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        lottery.requestRandomWords(false);

        vm.prank(owner);
        requestId = lottery.requestRandomWords(false);

        assertEq(
            uint256(lottery.currentState()),
            uint256(UpgradedLottery.LotteryState.CalculatingWinner)
        );
    }

    function _mockVRFFulfillment() internal {
        bytes memory callData = abi.encodeWithSignature(
            "rawFulfillRandomWords(uint256,uint256[])",
            requestId,
            _getRandomWords()
        );

        vm.prank(VRFCoordinator);
        (bool success, ) = address(lottery).call(callData);
        assertTrue(success, "VRF fulfillment failed");
    }

    function _getRandomWords() internal pure returns (uint256[] memory) {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345; // Some random value
        return randomWords;
    }

    function test_CompleteRoundAndWithdrawWinnings() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.prank(user2);
        lottery.supplyToken(user2, 500);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.updateState();

        vm.prank(owner);
        requestId = lottery.requestRandomWords(false);

        _mockVRFFulfillment();

        (, , , , uint256 prizePool, bool finished) = lottery.getRoundInfo(1);
        assertTrue(finished);
        assertEq(prizePool, 800);

        (, , , address winner, , ) = lottery.getRoundInfo(1);

        address nonWinner = winner == user1 ? user2 : user1;
        vm.prank(nonWinner);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.NotTheWinner.selector)
        );
        lottery.withdrawWinnings();

        uint256 balanceBefore = link.balanceOf(winner);
        vm.prank(winner);
        lottery.withdrawWinnings();
        uint256 balanceAfter = link.balanceOf(winner);

        assertEq(balanceAfter - balanceBefore, 800);

        (, , , , prizePool, ) = lottery.getRoundInfo(1);
        assertEq(prizePool, 0);
    }

    function test_StartNewRound() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.updateState();

        vm.prank(owner);
        requestId = lottery.requestRandomWords(false);

        _mockVRFFulfillment();

        uint256 nextStartTime = block.timestamp + 1 hours;
        uint256 nextEndTime = nextStartTime + 2 days;

        vm.prank(owner);
        lottery.startNewRound(nextStartTime, nextEndTime);

        assertEq(lottery.currentRoundId(), 2);

        (
            uint256 saleStartTime,
            uint256 saleEndTime,
            uint256 ticketCounter,
            address winner,
            uint256 prizePool,
            bool finished
        ) = lottery.getRoundInfo(2);

        assertEq(saleStartTime, nextStartTime);
        assertEq(saleEndTime, nextEndTime);
        assertEq(ticketCounter, 0);
        assertEq(winner, address(0));
        assertEq(prizePool, 0);
        assertEq(finished, false);
    }

    function test_FailStartRoundWithInvalidPeriod() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.updateState();

        vm.prank(owner);
        requestId = lottery.requestRandomWords(false);

        _mockVRFFulfillment();

        uint256 nextStartTime = block.timestamp + 1 hours;

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.InvalidSalePeriod.selector)
        );
        lottery.startNewRound(nextStartTime, nextStartTime);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.InvalidSalePeriod.selector)
        );
        lottery.startNewRound(nextStartTime + 1, nextStartTime);
    }

    function test_FailStartRoundIfCurrentNotFinished() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        uint256 nextStartTime = block.timestamp + 1 hours;
        uint256 nextEndTime = nextStartTime + 2 days;

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.RoundNotFinished.selector)
        );
        lottery.startNewRound(nextStartTime, nextEndTime);
    }

    function test_FailRequestRandomWordsIfNoTickets() public {
        vm.warp(block.timestamp + 1 days + 1);
        lottery.updateState();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.NoTicketsSold.selector)
        );
        lottery.requestRandomWords(false);
    }

    function test_FailRequestRandomWordsIfLotteryActive() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.LotteryActive.selector)
        );
        lottery.requestRandomWords(false);
    }

    function test_FailWithdrawBeforeRoundFinished() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.updateState();

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradedLottery.RoundNotFinished.selector)
        );
        lottery.withdrawWinnings();
    }

    function test_BuyTicketsInMultipleRounds() public {
        vm.prank(user1);
        lottery.supplyToken(user1, 300);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.updateState();

        vm.prank(owner);
        requestId = lottery.requestRandomWords(false);

        _mockVRFFulfillment();

        uint256 nextStartTime = block.timestamp + 1 hours;
        uint256 nextEndTime = nextStartTime + 2 days;

        vm.prank(owner);
        lottery.startNewRound(nextStartTime, nextEndTime);

        vm.warp(nextStartTime + 1);
        lottery.updateState();

        vm.prank(user1);
        lottery.supplyToken(user1, 400);

        vm.prank(user2);
        lottery.supplyToken(user2, 600);

        assertEq(lottery.getTicketCount(1, user1), 3);
        assertEq(lottery.getTicketCount(1, user2), 0);

        assertEq(lottery.getTicketCount(2, user1), 4);
        assertEq(lottery.getTicketCount(2, user2), 6);

        (, , uint256 round1Tickets, , , ) = lottery.getRoundInfo(1);
        (, , uint256 round2Tickets, , , ) = lottery.getRoundInfo(2);

        assertEq(round1Tickets, 3);
        assertEq(round2Tickets, 10);
    }
}
