//SPDX-License-Identifier: MIT
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title DebtRebaseToken
 * @author BatuBlockDev
 * @notice The following contract is used to show the debt balances from the loans made by the users.
 * also the contract track the payments made by the users over time to manage the users scores
 * as well as apply fees to the users.
 */

contract DebtRebaseToken is ERC20, Ownable, AccessControl {
    constructor() ERC20("NFTBANK", "DEBT") Ownable(msg.sender) {}

    struct loanData {
        uint256 loanId;
        uint256 loanBalance;
        uint256 rate;
        uint256 typeInterest;
        uint256 startTime;
        uint256 endTime;
        uint256 lastPaymentTime;
        uint256 term;
        uint256 leftTerms;
        uint256 interval;
        uint256 amount;
        uint256 penaltyAmount;
        address borrower;
    }

    struct borrowerData {
        uint256[] loanIds;
        uint256 totalLoanAmount;
        uint256 totalPaidAmount;
        uint256 totalPenaltyAmount;
        uint256 score;
    }
    mapping(uint256 loanId => loanData) loanInfo;
    mapping(address borrower => borrowerData) borrowerInfo;

    function setLoanData(
        uint256 loanId,
        uint256 rate,
        uint256 typeInterest,
        uint256 term,
        uint256 interval,
        address borrower,
        uint256 amount
    ) external {
        loanInfo[loanId].loanId = loanId;
        loanInfo[loanId].rate = rate;
        loanInfo[loanId].typeInterest = typeInterest;
        loanInfo[loanId].startTime = block.timestamp;
        loanInfo[loanId].endTime = block.timestamp + (term * interval);
        loanInfo[loanId].term = term;
        loanInfo[loanId].interval = interval;
        loanInfo[loanId].borrower = borrower;
        loanInfo[loanId].amount = amount;
    }

    function mint(uint256 loanId, uint256 amount, address borrower) external {
        loanInfo[loanId].loanBalance += amount;
        borrowerInfo[borrower].totalLoanAmount += amount;
        borrowerInfo[borrower].loanIds.push(loanId);
        _mint(borrower, amount);
    }

    function burn(uint256 loanId, uint256 amount, address borrower) external {
        loanInfo[loanId].loanBalance -= amount;
        loanInfo[loanId].leftTerms--;
        loanInfo[loanId].lastPaymentTime = block.timestamp;
        borrowerInfo[borrower].totalPaidAmount += amount;
        _burn(borrower, amount);
    }

    function amountPayEachInterval(
        uint256 loanId
    ) public view returns (uint256) {
        uint256 loanAmount = balanceOfLoan(loanId);
        uint256 rate = loanInfo[loanId].rate;
        uint256 typeInterest = loanInfo[loanId].typeInterest;
        uint256 leftTerms = loanInfo[loanId].leftTerms;
        uint256 intervalRate = rate / leftTerms;

        if (typeInterest == 0) {
            // Simple interest
            return loanAmount / leftTerms;
        } else if (typeInterest == 1) {
            // Compound interest
            uint256 data = 1 + (intervalRate / 100);
            for (uint256 i = 0; i < leftTerms; i++) {
                data += (data * (1 + (intervalRate / 100)));
            }
            uint256 denominador = loanAmount * intervalRate * data;
            uint256 numerador = data - 1;
            return (denominador / numerador);
        }
    }

    function balanceOfLoan(uint256 loanId) public view returns (uint256) {
        uint256 timeNoPayment = block.timestamp -
            loanInfo[loanId].lastPaymentTime;
        if ((timeNoPayment / 1 days) > (loanInfo[loanId].interval + 3 days)) {
            // 3 days grace period
            // 0.15% penalty per day
            // 0.15% = 0.0015
            uint256 ecu;
            for (uint96 i = 0; i < timeNoPayment; i++) {
                ecu = (10015 * timeNoPayment) / 10000;
            }
            uint256 penaltyAmount = loanInfo[loanId].loanBalance * ecu;
            return (penaltyAmount);
        } else {
            return (loanInfo[loanId].loanBalance);
        }
    }

    function balanceOf(
        address borrower
    ) public view virtual override returns (uint256) {
        uint256 totalDebtLoanAmount = 0;
        uint256 numberOfLoans = borrowerInfo[borrower].loanIds.length;
        for (uint256 i = 0; i < numberOfLoans; i++) {
            uint256 loanId = borrowerInfo[borrower].loanIds[i];
            totalDebtLoanAmount += balanceOfLoan(loanId);
        }
        return (totalDebtLoanAmount);
    }
}
