// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;
import {Test, Vm, console} from "forge-std/Test.sol";
import {Lottery} from "../contracts/Lottery.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

contract LotteryTest is Test {
    Lottery public lottery;

    address public owner;
    address public user1;
    address public user2;

    address chainLinkToken = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address chainLinkVRFWrapper = 0x02aae1A04f9828517b3007f83f6181900CaD910c;
    IERC20 link = IERC20(chainLinkToken);

    uint256 public constant TICKET_PRICE = 100;
    uint256 public constant INITIAL_BALANCE = 1000 * TICKET_PRICE;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.createSelectFork(
            "https://eth-mainnet.g.alchemy.com/v2/zNMGaVTfo_oc5Wngx6AQHIKUhcTXsCJD"
        );

        vm.startPrank(owner);

        // Deploy lottery
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        lottery = new Lottery(
            address(chainLinkToken),
            startTime,
            endTime,
            address(chainLinkVRFWrapper)
        );

        // // Mint tokens
        // token.mint(user1, INITIAL_BALANCE);
        // token.mint(user2, INITIAL_BALANCE);

        deal(address(link), user1, 1 ether);

        uint256 balanceOfUser1 = IERC20(
            0x514910771AF9Ca656af840dff83E8264EcF986CA
        ).balanceOf(user1);

        console.log("balance of user1", balanceOfUser1);
        // uint256 balanceUser1 = token.balanceOf(user1);
        // console.log("balance of user1:", balanceUser1);

        vm.stopPrank();

        vm.startPrank(user1);
        link.approve(address(lottery), 1 ether);
        console.log(
            "Allowance for Lottery:",
            link.allowance(user1, address(lottery))
        );
        vm.stopPrank();

        vm.startPrank(user2);
        link.approve(address(this), 1 ether);
        vm.stopPrank();
    }

    function test_InitialState() public {
        // Your test code here

        uint256 test = lottery.token().totalSupply();

        console.log("tokens", test);
        assertEq(
            uint256(lottery.currentState()),
            uint256(Lottery.LotteryState.TicketSaleOpen)
        );
    }

    function test_GetTicketCount() public {
        console.log("User1 LINK balance:", link.balanceOf(user1));
        console.log(
            "Allowance before supply:",
            link.allowance(user1, address(lottery))
        );

        vm.prank(user1);
        uint256 firstSupply = lottery.supplyToken(user1, 300);
        console.log("Tickets issued:", firstSupply);

        uint256[] memory tickets = lottery.getTicketBalance(user1);
        assertEq(tickets.length, 3);
        assertEq(tickets[0], 1);
        assertEq(tickets[1], 2);
        assertEq(tickets[2], 3);
    }
    function test_FailSupplyTokenInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(Lottery.InsufficientBalance.selector)
        );
        lottery.supplyToken(user1, 2 ether); // More than user1's balance (1 ether)
    }

    function test_Supply0Tokens() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Lottery.AmountZero.selector));
        lottery.supplyToken(user1, 0);
    }
}
