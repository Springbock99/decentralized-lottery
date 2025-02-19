// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Lottery} from "../contracts/Lottery.sol";
import {MockToken} from "../contracts/MockToken.sol";
import {MockVRFCoordinator} from "../contracts/MockVRFCoordinator.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    MockToken public token;
    MockVRFCoordinator public vrfCoordinator;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant TICKET_PRICE = 100;
    uint256 public constant INITIAL_BALANCE = 1000 * TICKET_PRICE;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.createSelectFork(
            "https://eth-mainnet.g.alchemy.com/v2/zNMGaVTfo_oc5Wngx6AQHIKUhcTXsCJD",
            19_000_000
        );

        vm.startPrank(owner);

        // Deploy mock token first
        token = new MockToken("Mock LINK", "mLINK");
        console.log("MockToken deployed at:", address(token));

        // Deploy mock VRF coordinator with the token address
        vrfCoordinator = new MockVRFCoordinator(address(token));
        console.log("VRFCoordinator deployed at:", address(vrfCoordinator));

        // Deploy lottery
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        lottery = new Lottery(
            address(0x514910771AF9Ca656af840dff83E8264EcF986CA),
            startTime,
            endTime,
            address(vrfCoordinator)
        );
        console.log("Lottery deployed at:", address(lottery));

        // Mint tokens
        token.mint(user1, INITIAL_BALANCE);
        token.mint(user2, INITIAL_BALANCE);

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

    // function test_SimpleSupply() public {
    //     vm.startPrank(user1);
    //     lottery.supplyToken(user1, 100);

    //     uint256 lotterBalance = Lottery.getBalance(address(this));

    //     assertEq(lotterBalance, 100);
    // }
}
