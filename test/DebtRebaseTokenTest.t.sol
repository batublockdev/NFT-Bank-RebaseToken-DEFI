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
        mockERC721.mint(lender);
    }

    modifier loan(uint256 x) {
        x = 1;
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
        if (x == 0) {
            vault.offerLoan(loanIdx, 1000 ether, 10, 1, 12, 1, address(token));
        }
        if (x == 1) {
            vault.offerLoan(loanIdx, 1000 ether, 10, 0, 12, 1, address(token));
        }
        if (x == 2) {
            vault.offerLoan(loanIdx, 1000 ether, 10, 0, 12, 0, address(token));
        }
        if (x == 3) {
            vault.offerLoan(loanIdx, 1000 ether, 10, 1, 12, 0, address(token));
        }
        vm.stopPrank();
        uint256 offerId = vault.offerIds(0);
        vm.prank(borrower);
        vault.approveLoan(loanIdx, offerId);
        _;
    }

    ////////////////////////////////////////
    //////////////  BANK TESTS /////////////
    ////////////////////////////////////////
    function test_mint(uint256 x) public loan(x) {
        assertEq(userBalance, rebaseToken.superBalanceOf(borrower));
    }

    function test_burn(uint256 x) public loan(x) {
        assertEq(userBalance, rebaseToken.superBalanceOf(borrower));
        console.log(
            "Debt plus interest: ",
            rebaseToken.totalloanPlusInterest(loanId)
        );
        for (uint i = 0; i < rebaseToken.getTerms(loanId); i++) {
            uint256 amountToPayEach = rebaseToken.amountPayEachInterval(loanId);
            token.mint(borrower, amountToPayEach);
            vm.prank(borrower);
            token.approve(address(vault), amountToPayEach);
            console.log(
                "Debt balance after : #",
                i,
                " ",
                rebaseToken.getBalaceOfLoan(loanId)
            );
            console.log(
                "balance after : #",
                i,
                " ",
                rebaseToken.superBalanceOf(borrower)
            );
            vm.prank(borrower);
            vault.payLoan(loanId);
        }
        assertEq(0, rebaseToken.superBalanceOf(borrower));
    }

    function test_fee(uint256 x) public loan(x) {
        uint256 amountPay = rebaseToken.amountPayEachInterval(loanId);
        uint256 penalty;
        if (rebaseToken.getTotalPenaltyLoan(loanId) == 0) {
            penalty = 0;
        } else {
            penalty = rebaseToken.getTotalPenaltyLoan(loanId);
        }
        uint256 penaltyAmount = penalty / rebaseToken.getTerms(loanId);
        uint256 interest = rebaseToken.getTotalInterest(loanId);
        console.log("Interest total ", interest);
        uint256 interestPerInterval = (interest) / rebaseToken.getTerms(loanId);
        uint256 base = amountPay - interestPerInterval;
        console.log("Base :", base);
        console.log("Base total:", base * rebaseToken.getTerms(loanId));
        console.log("Interest ", interestPerInterval);
        uint256 protocolFee = ((interestPerInterval + penaltyAmount) * 3) / 100;
        console.log("fee: ", protocolFee);
    }

    function test_payLoan_Total(uint256 x) public loan(x) {
        uint256 debtBefore = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceBefore = rebaseToken.balanceOf(borrower);

        console.log("Debt Amount: ", debtBefore);
        console.log("Balance Amount: ", balanceBefore);
        for (uint i = 0; i < 2; i++) {
            uint256 amountToPayEach = rebaseToken.amountPayEachInterval(loanId);
            token.mint(borrower, amountToPayEach);
            vm.prank(borrower);
            token.approve(address(vault), amountToPayEach);
            vm.prank(borrower);
            vault.payLoan(loanId);
        }
        uint256 amountToPayTotal = rebaseToken.amountPayTotal(loanId);
        token.mint(borrower, amountToPayTotal);
        vm.prank(borrower);
        token.approve(address(vault), amountToPayTotal);
        vm.prank(borrower);
        vault.payLoanTotal(loanId);

        uint256 debtAfter = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceAfter = rebaseToken.balanceOf(borrower);

        console.log("Debt Amount: ", debtAfter);
        console.log("Balance Amount: ", balanceAfter);
        console.log("Balance Vault: ", token.balanceOf(address(vault)));
        console.log("Balance Lender: ", token.balanceOf(lender));
        address nftOwner = mockERC721.ownerOf(0);

        assertEq(nftOwner, borrower);
    }

    function test_Vault__NotOwnerOfNFT() public {
        vm.prank(borrower);
        mockERC721.approve(address(vault), 0);
        vm.prank(borrower);
        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.Vault__NotOwnerOfNFT.selector,
                address(mockERC721),
                1
            )
        );
        vault.requestLoan(
            10,
            1,
            12,
            1,
            1000 ether,
            address(0),
            address(mockERC721),
            1
        );
    }

    function test_Vault__NotApprovedForToken() public {
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
        token.approve(address(vault), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.Vault__NotApprovedForToken.selector,
                address(token)
            )
        );
        vm.startPrank(lender);
        vault.offerLoan(loanIdx, 1000 ether, 10, 1, 12, 1, address(token));
        vm.stopPrank();
    }

    function test_Vault__TypeInterestNotValid() public {
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.Vault__TypeInterestNotValid.selector,
                15
            )
        );
        vm.startPrank(lender);
        vault.offerLoan(loanIdx, 1000 ether, 10, 15, 12, 1, address(token));
        vm.stopPrank();
    }

    function test_Vault__IntervalNotValid() public {
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
        vm.expectRevert(
            abi.encodeWithSelector(Vault.Vault__IntervalNotValid.selector, 8)
        );
        vm.startPrank(lender);
        vault.offerLoan(loanIdx, 1000 ether, 10, 1, 12, 8, address(token));
        vm.stopPrank();
    }

    function test_Vault__TokenNotValid() public {
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.Vault__TokenNotValid.selector,
                address(0)
            )
        );
        vm.startPrank(lender);
        vault.offerLoan(loanIdx, 1000 ether, 10, 1, 12, 1, address(0));
        vm.stopPrank();
    }

    function test_Vault__NotApprovedForNFT() public {
        vm.prank(borrower);
        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.Vault__NotApprovedForNFT.selector,
                address(mockERC721),
                0
            )
        );
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
    }

    function test_Vault__loanNotFound() public {
        test_payLoan_Total(0);
        uint256 amountToPayTotal = 1000 ether;
        token.mint(borrower, amountToPayTotal);
        vm.prank(borrower);
        token.approve(address(vault), amountToPayTotal);
        vm.expectRevert(
            abi.encodeWithSelector(Vault.Vault__loanNotFound.selector, loanId)
        );
        vm.prank(borrower);
        vault.payLoanTotal(loanId);
    }

    function test_DebtRebaseToken__LoanDoesNotExist() public {
        test_payLoan_Total(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                DebtRebaseToken.DebtRebaseToken__LoanDoesNotExist.selector,
                loanId
            )
        );
        uint256 debtBefore = rebaseToken.totalloanPlusInterest(loanId);
    }

    function test_payLoan(uint256 x) public loan(x) {
        uint256 debtBefore = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceBefore = rebaseToken.balanceOf(borrower);

        console.log("Debt Amount: ", debtBefore);
        console.log("Balance Amount: ", balanceBefore);
        for (uint i = 0; i < rebaseToken.getTerms(loanId); i++) {
            uint256 amountToPayEach = rebaseToken.amountPayEachInterval(loanId);
            token.mint(borrower, amountToPayEach);
            vm.prank(borrower);
            token.approve(address(vault), amountToPayEach);
            vm.prank(borrower);
            vault.payLoan(loanId);
        }

        uint256 debtAfter = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceAfter = rebaseToken.balanceOf(borrower);

        console.log("Debt Amount: ", debtAfter);
        console.log("Balance Amount: ", balanceAfter);
        console.log("Balance Vault: ", token.balanceOf(address(vault)));
        console.log("Balance Lender: ", token.balanceOf(lender));
        address nftOwner = mockERC721.ownerOf(0);

        assertEq(nftOwner, borrower);
    }

    function test_penalty_Increase(uint256 x) public loan(x) {
        uint256 debtBefore = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceBefore = rebaseToken.balanceOf(borrower);

        console.log("Debt Amount: ", debtBefore);
        console.log("Balance Amount: ", balanceBefore);

        vm.warp(block.timestamp + 100 days);

        vault.updateLoanState(loanId);

        uint256 debtAfter2 = rebaseToken.getBalaceOfLoan(loanId);
        uint256 balanceAfter2 = rebaseToken.balanceOf(borrower);

        console.log("Balance Amount2: ", balanceAfter2);
        console.log("Debt Amount2: ", debtAfter2);
        address nftOwner = mockERC721.ownerOf(0);

        assertEq(nftOwner, lender);
    }

    function test_totalamountEqualtoAmountoPey(uint256 x) public loan(x) {
        loanId = vault.loanIds(0);
        uint256 amountToPayEach = rebaseToken.amountPayEachInterval(loanId);
        uint256 totalAmount = rebaseToken.amountPayTotal(loanId);
        console.log("Total Amount Expected: ", amountToPayEach);
        console.log("Total Amount: ", totalAmount);
        /* assertEq(
            totalAmount,
            (amountToPayEach * rebaseToken.getLeftTerm(loanId)),
            "Total Amount is  equal to Amount to Pay Each Interval multiply by the terms"
        );*/
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

    function test_interestLoanCompound(uint256 x) public loan(x) {
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
