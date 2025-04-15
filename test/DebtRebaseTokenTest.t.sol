//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DebtRebaseToken} from "../src/DebtRebaseToken.sol";
import {IRebaseToken} from "../src/Interface/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "./mock/ERC20Mock.sol";
import {ERC721Mock} from "./mock/ERC721Mock.sol";

contract RebaseTokenTest is Test {
    //USERS
    address public owner = makeAddr("owner");
    address public borrower = makeAddr("borrower");
    address public lender = makeAddr("lender");

    uint256 public userBalance = 1000 ether;
    ERC20Mock token;
    uint256 private constant PRECISION_FACTOR = 1e18;

    uint256 public loanId;

    DebtRebaseToken private rebaseToken;
    Vault private vault;
    ERC721Mock private mockERC721;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new DebtRebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.transferOwnership(address(vault));
        vm.stopPrank();
        // Set up the mock ERC20 token
        token = new ERC20Mock("Mock Token", "MOCK", userBalance, lender);

        // Mint some NFTs for the users
        mockERC721 = new ERC721Mock("MockNFT", "MNFT");
        mockERC721.mint(borrower);
    }

    modifier loan() {
        vm.prank(borrower);
        mockERC721.approve(address(vault), 0);
        vm.prank(borrower);
        vault.requestLoan(
            10,
            1,
            12,
            1,
            1000 ether,
            address(0),
            address(mockERC721),
            0
        );
        uint256 loanIdx = vault.loanIds(0);
        vm.prank(lender);
        token.approve(address(vault), 1000 ether);
        vm.startPrank(lender);
        vault.offerLoan(loanIdx, 1000 ether, 10, 1, 12, 1, address(token));
        vm.stopPrank();
        uint256 offerId = vault.offerIds(0);
        vm.prank(borrower);
        vault.approveLoan(loanIdx, offerId);
        _;
    }

    ////////////////////////////////////////
    //////////////  MATH TESTS /////////////
    ////////////////////////////////////////

    ////////////////////////////////////////
    //////////////  MATH TESTS /////////////
    ////////////////////////////////////////
    function test_totalamountEqualtoAmountoPey() public loan {
        loanId = vault.loanIds(0);
        uint256 amountToPayEach = rebaseToken.amountPayEachInterval(loanId);
        uint256 totalAmount = rebaseToken.amountPayTotal(loanId);
        uint256 totalAmountExpected = amountToPayEach * 12;
        console.log("Total Amount Expected: ", totalAmountExpected);
        console.log("Total Amount: ", totalAmount);
    }

    function test_amountPayEachInterval() public {
        uint256 amount = 1000 ether;
        uint256 term = 12;
        uint256 intervalRate = 1;
        uint256 loanAmount = amount;
        uint256 leftTerms = term;

        // Compound interest calculation with overflow protection
        uint256 data = PRECISION_FACTOR +
            ((intervalRate * PRECISION_FACTOR) / 100);
        for (uint256 i = 0; i < leftTerms - 1; i++) {
            data =
                (data *
                    (PRECISION_FACTOR +
                        ((intervalRate * PRECISION_FACTOR) / 100))) /
                PRECISION_FACTOR;
        }
        console.log("Data: ", data);
        uint256 denominador = (loanAmount *
            ((intervalRate * PRECISION_FACTOR) / 100) *
            data) / PRECISION_FACTOR;
        uint256 numerador = data - PRECISION_FACTOR;
        uint256 result = denominador / numerador;

        console.log("Total Amount: ", result);
    }

    function test_penalty() public {
        uint256 amount = 1000 ether;
        uint256 lastPaymentTime = block.timestamp;
        uint256 interval = 30 days;
        uint256 penaltyRate = 2 * 1e15; // 0.2% penalty rate

        vm.warp(block.timestamp + 200 days);
        vm.warp(block.timestamp + 5 hours);

        uint256 timeNoPayment = block.timestamp - lastPaymentTime;
        if (timeNoPayment > (interval + 3 days)) {
            console.log("Estamo en penalty: ", timeNoPayment);
            console.log("Estamo en penalty: ", timeNoPayment / 1 days);
            console.log(
                "Days without paying ",
                (timeNoPayment - (interval + 3 days)) / 1 days
            );
            console.log(
                "Intervals without paying ",
                (timeNoPayment - (interval + 3 days)) / interval
            );
            uint256 ecu = (PRECISION_FACTOR + penaltyRate);
            for (
                uint96 i = 0;
                i < ((timeNoPayment - (interval + 3 days)) / 1 days) - 1;
                i++
            ) {
                ecu =
                    (ecu * (PRECISION_FACTOR + penaltyRate)) /
                    PRECISION_FACTOR;
            }
            uint256 penaltyAmount = (amount * ecu) / PRECISION_FACTOR;
            console.log("Penalty Amount: ", penaltyAmount);
        }
    }
}
