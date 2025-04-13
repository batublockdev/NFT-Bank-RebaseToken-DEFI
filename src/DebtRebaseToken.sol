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
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private penaltyRate = 2 * 1e15; // 0.2% penalty rate
    uint256 private daysGracePeriod = 3 days; // 3 days grace period

    constructor() ERC20("NFTBANK", "DEBT") Ownable(msg.sender) {}

    struct loanData {
        uint256 loanId;
        uint256 loanBalance;
        uint256 rate;
        uint256 typeInterest;
        uint256 endTime;
        uint256 lastPaymentTime;
        uint256 term;
        uint256 leftTerms;
        uint256 interval;
        uint256 amount;
        uint256 penaltyAmount;
        uint256 interestAmount;
        uint256 missedPayments;
        address borrower;
    }

    struct borrowerData {
        address borrower;
        uint256[] loanIds;
        uint256 totalLoanAmount;
        uint256 totalPaidAmount;
        uint256 totalPenaltyAmount;
        uint256 score;
    }
    mapping(uint256 loanId => loanData) loanInfo;
    mapping(address borrower => borrowerData) borrowerInfo;

    function setPenaltyRate(uint256 _newPenaltyRate) external onlyOwner {
        penaltyRate = ((_newPenaltyRate * PRECISION_FACTOR) / 100);
    }

    function setdaysGracePeriod(
        uint256 _newDaysGracePeriod
    ) external onlyOwner {
        daysGracePeriod = _newDaysGracePeriod;
    }

    function setBorrowerData(address borrower) external {
        borrowerInfo[borrower].borrower = borrower;
        borrowerInfo[borrower].score = 100;
    }

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
        loanInfo[loanId].rate = (rate * PRECISION_FACTOR) / 100;
        loanInfo[loanId].typeInterest = typeInterest;
        loanInfo[loanId].endTime = block.timestamp + (term * interval);
        loanInfo[loanId].term = term;
        loanInfo[loanId].interval = interval;
        loanInfo[loanId].borrower = borrower;
        loanInfo[loanId].amount = amount;
        loanInfo[loanId].leftTerms = term;
        loanInfo[loanId].loanBalance = amount;
        loanInfo[loanId].lastPaymentTime = block.timestamp;
        borrowerInfo[borrower].loanIds.push(loanId);
    }

    function mint(uint256 loanId, uint256 amount, address borrower) external {
        loanInfo[loanId].loanBalance += amount;
        borrowerInfo[borrower].totalLoanAmount += amount;
        _mint(borrower, amount);
    }

    function burn(uint256 loanId, uint256 amount, address borrower) external {
        loanInfo[loanId].loanBalance -= amount;
        loanInfo[loanId].leftTerms--;
        loanInfo[loanId].lastPaymentTime = block.timestamp;
        borrowerInfo[borrower].totalPaidAmount += amount;
        _burn(borrower, amount);
        if (
            loanInfo[loanId].leftTerms == 0 || loanInfo[loanId].loanBalance == 0
        ) {
            delete loanInfo[loanId];
        }
    }

    function loanState(uint256 loanId) external {
        if (checkLoanMisses(loanId)) {
            CleanLoan(loanId);
        } else {
            checkLoanPenalty(loanId);
        }
    }

    function CleanLoan(uint256 loanId) internal {
        uint256 amount = loanInfo[loanId].loanBalance;
        _burn(loanInfo[loanId].borrower, amount);
        delete loanInfo[loanId];
    }

    function checkLoanMisses(uint256 loanId) internal view returns (bool) {
        uint256 timeNoPayment = block.timestamp -
            loanInfo[loanId].lastPaymentTime;
        uint256 interval = loanInfo[loanId].interval;
        if (timeNoPayment > (interval + daysGracePeriod)) {
            if (
                (timeNoPayment - (interval + daysGracePeriod)) >
                ((interval + daysGracePeriod) * 2)
            ) {
                return true;
            } else {
                return false;
            }
        }
    }

    function checkLoanPenalty(uint256 loanId) internal {
        uint256 checkedBalance = balanceOfLoan(loanId);
        uint256 uncheckedBalance = loanInfo[loanId].loanBalance;
        if (checkedBalance > uncheckedBalance) {
            uint256 penalty = (checkedBalance - uncheckedBalance);
            loanInfo[loanId].penaltyAmount += penalty;
            borrowerInfo[loanInfo[loanId].borrower]
                .totalPenaltyAmount += penalty;
            borrowerInfo[loanInfo[loanId].borrower].score -= penalty;
            loanInfo[loanId].loanBalance = checkedBalance;
            _mint(loanInfo[loanId].borrower, penalty);
            // Emit an event for the penalty
        }
    }

    function amountPayTotal(uint256 loanId) public view returns (uint256) {
        uint256 loanAmount = balanceOfLoan(loanId);
        uint256 rate = loanInfo[loanId].rate;
        uint256 typeInterest = loanInfo[loanId].typeInterest;
        uint256 term = loanInfo[loanId].leftTerms;
        uint256 interval = loanInfo[loanId].interval;

        if (typeInterest == 0) {
            // Simple interest
            return
                loanAmount +
                interestLoanSimple(interval, rate, term, loanAmount);
        } else if (typeInterest == 1) {
            // Compound interest
            return interestLoanCompound(interval, rate, term, loanAmount);
        }
    }

    function amountPayEachInterval(
        uint256 loanId
    ) public view returns (uint256) {
        uint256 loanAmount = balanceOfLoan(loanId);
        uint256 rate = loanInfo[loanId].rate;
        uint256 typeInterest = loanInfo[loanId].typeInterest;
        uint256 leftTerms = loanInfo[loanId].leftTerms;
        uint256 intervalRate = rate / leftTerms;
        uint256 amount = loanInfo[loanId].amount;
        uint256 interval = loanInfo[loanId].interval;

        if (typeInterest == 0) {
            // Simple interest
            return
                interestLoanSimple(interval, rate, leftTerms, amount) /
                leftTerms;
        } else if (typeInterest == 1) {
            // Compound interest
            uint256 data = PRECISION_FACTOR + intervalRate;
            for (uint256 i = 0; i < leftTerms - 1; i++) {
                data =
                    (data * (PRECISION_FACTOR + intervalRate)) /
                    PRECISION_FACTOR;
            }
            uint256 denominador = (loanAmount * (intervalRate) * data) /
                PRECISION_FACTOR;
            uint256 numerador = data - PRECISION_FACTOR;
            return denominador / numerador;
        }
    }

    function balanceOfLoan(uint256 loanId) public view returns (uint256) {
        uint256 timeNoPayment = block.timestamp -
            loanInfo[loanId].lastPaymentTime;
        uint256 interval = loanInfo[loanId].interval;
        uint256 amount = loanInfo[loanId].loanBalance;

        if (timeNoPayment > (interval + daysGracePeriod)) {
            uint256 ecu = (PRECISION_FACTOR + penaltyRate);
            for (
                uint96 i = 0;
                i <
                ((timeNoPayment - (interval + daysGracePeriod)) / 1 days) - 1;
                i++
            ) {
                ecu =
                    (ecu * (PRECISION_FACTOR + penaltyRate)) /
                    PRECISION_FACTOR;
            }
            return (amount * ecu) / PRECISION_FACTOR;
        }
        {
            return (loanInfo[loanId].loanBalance);
        }
    }

    function totalloanPlusInterest(
        uint256 loanId
    ) public view returns (uint256) {
        uint256 amount = loanInfo[loanId].amount;
        uint256 rate = loanInfo[loanId].rate;
        uint256 typeInterest = loanInfo[loanId].typeInterest;
        uint256 term = loanInfo[loanId].term;
        uint256 interval = loanInfo[loanId].interval;

        if (typeInterest == 0) {
            // Simple interest
            return amount + interestLoanSimple(interval, rate, term, amount);
        } else if (typeInterest == 1) {
            // Compound interest
            return interestLoanCompound(interval, rate, term, amount);
        }
    }

    function interestLoanSimple(
        uint256 interval,
        uint256 rate,
        uint256 term,
        uint256 amount
    ) public pure returns (uint256) {
        if (interval == 15 days) {
            return (amount * (rate / 24)) * term;
        } else {
            return (amount * (rate / 12)) * term;
        }
    }

    function interestLoanCompound(
        uint256 interval,
        uint256 rate,
        uint256 term,
        uint256 amount
    ) public pure returns (uint256) {
        if (interval == 15 days) {
            uint256 result = amount * (PRECISION_FACTOR + (rate / 24));
            for (uint256 i = 0; i < term - 1; i++) {
                result =
                    (result * (amount * (PRECISION_FACTOR + (rate / 24)))) /
                    PRECISION_FACTOR;
            }
            return result;
        } else {
            uint256 result = amount * (PRECISION_FACTOR + (rate / 12));
            for (uint256 i = 0; i < term - 1; i++) {
                result =
                    (result * (amount * (PRECISION_FACTOR + (rate / 12)))) /
                    PRECISION_FACTOR;
            }
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
