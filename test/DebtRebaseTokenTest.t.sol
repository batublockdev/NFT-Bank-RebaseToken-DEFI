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
        loanId = vault.loanIds(0);
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
    //////////////  BANK TESTS /////////////
    ////////////////////////////////////////
    function test_payLoan() public loan {
        uint256 debtBefore = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceBefore = rebaseToken.balanceOf(borrower);

        console.log("Debt Amount: ", debtBefore);
        console.log("Balance Amount: ", balanceBefore);
        uint256 amountToPayEach = rebaseToken.amountPayEachInterval(loanId);
        token.mint(borrower, amountToPayEach);
        vm.prank(borrower);
        token.approve(address(vault), amountToPayEach);
        vm.prank(borrower);
        vault.payLoan(loanId);

        uint256 debtAfter = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceAfter = rebaseToken.balanceOf(borrower);

        console.log("Debt Amount: ", debtAfter);
        console.log("Balance Amount: ", balanceAfter);
    }

    function test_penalty_Increase() public loan {
        uint256 debtBefore = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceBefore = rebaseToken.balanceOf(borrower);

        console.log("Debt Amount: ", debtBefore);
        console.log("Balance Amount: ", balanceBefore);

        address nftOwner = mockERC721.ownerOf(0);

        assertEq(nftOwner, address(vault));

        vm.warp(block.timestamp + 60 days);
        vault.updateLoanState(loanId);

        uint256 debtAfter = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceAfter = rebaseToken.balanceOf(borrower);

        console.log("Balance Amount2: ", balanceAfter);
        console.log("Debt Amount2: ", debtAfter);

        nftOwner = mockERC721.ownerOf(0);

        assertEq(nftOwner, address(vault));

        vm.warp(block.timestamp + 80 days);

        vault.updateLoanState(loanId);

        uint256 debtAfter2 = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceAfter2 = rebaseToken.balanceOf(borrower);

        console.log("Balance Amount2: ", balanceAfter2);
        console.log("Debt Amount2: ", debtAfter2);
        nftOwner = mockERC721.ownerOf(0);

        assertEq(nftOwner, lender);
    }

    function test_totalamountEqualtoAmountoPey() public loan {
        loanId = vault.loanIds(0);
        uint256 amountToPayEach = rebaseToken.amountPayEachInterval(loanId);
        uint256 totalAmount = rebaseToken.amountPayTotal(loanId);
        console.log("Total Amount Expected: ", amountToPayEach);
        console.log("Total Amount: ", totalAmount);
        assertEq(
            totalAmount,
            (amountToPayEach * rebaseToken.getLeftTerm(loanId)),
            "Total Amount is  equal to Amount to Pay Each Interval multiply by the terms"
        );
    }

    ////////////////////////////////////////
    //////////////  MATH TESTS /////////////
    ////////////////////////////////////////
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

    function test_interestLoanCompound() public loan {
        uint256 interval = 30 days;
        uint256 rate = (10 * 1e18) / 100; // 10% interest rate
        uint256 term = 12; // 12 months
        uint256 amount = 1000 ether; // Principal amount
        uint256 amountBalanceOf = rebaseToken.getBalaceOfLoan(loanId);
        console.log("Amount: ", amount);
        console.log("Amount2: ", amountBalanceOf);

        uint256 periods;
        if (interval == 15 days) {
            periods = 24; // bi-monthly
        } else {
            periods = 12; // monthly
        }

        // (1 + r)
        uint256 base = PRECISION_FACTOR + (rate / periods);
        uint256 exponent = term;

        // Compound: (1 + r)^n using exponentiation by squaring
        uint256 factor = PRECISION_FACTOR;
        while (exponent > 0) {
            if (exponent % 2 == 1) {
                factor = (factor * base) / PRECISION_FACTOR;
            }
            base = (base * base) / PRECISION_FACTOR;
            exponent /= 2;
        }
        console.log("Factor: ", factor);
        console.log("Factor: ", base);

        // Final amount = principal * compound factor
        uint256 result = (amount * factor) / PRECISION_FACTOR;
        uint256 result2 = (amountBalanceOf * factor) / PRECISION_FACTOR;

        console.log("Final Amount: ", result);
        console.log("Final Amount: ", result2);
    }
}
