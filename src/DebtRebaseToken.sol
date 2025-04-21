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
    // ------ Errors ---------
    error DebtRebaseToken__LoanDoesNotExist(uint256 loanId);
    error DebtRebaseToken__AlreadyExist(uint256 loanId);
    error DebtRebaseToken__IntervalNotCorrect(uint256 interval);
    error DebtRebaseToken__TranferNotAllowed();

    // ------ Type Declarations ---------
    enum InterestType {
        Simple,
        Compound
    }
    enum LoanState {
        Ok,
        MissedPennaltyApplied,
        Liquidated
    }

    // -------State Variables ---------
    struct loanData {
        uint256 loanId;
        uint256 loanBalance;
        uint256 rate;
        InterestType typeInterest;
        uint256 endTime;
        uint256 lastUpdateTime;
        uint256 lastPayTime;
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
        address addressBorrower;
        uint256[] loanIds;
        uint256 totalLoanAmount;
        uint256 totalPaidAmount;
        uint256 totalPenaltyAmount;
        uint256 score;
    }
    // The precision factor is used to handle decimal calculations
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private constant POINTS_SCORE_PENALTY = 10;
    uint256 private s_penaltyRate = 2 * 1e15; // 0.2% penalty rate
    uint256 private s_daysGracePeriod = 3 days; // 3 days grace period
    mapping(uint256 loanId => loanData) loanInfo;
    mapping(address borrower => borrowerData) borrowerInfo;

    // -------Events ---------
    event liquidate(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 indexed amount
    );
    event CompletePaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 indexed amount
    );
    // ------Modifiers ---------

    modifier loanExists(uint256 loanId) {
        if (loanInfo[loanId].loanId == 0) {
            revert DebtRebaseToken__LoanDoesNotExist(loanId);
        }
        _;
    }

    constructor() ERC20("NFTBANK", "DEBT") Ownable(msg.sender) {}

    /**
     *
     * @param _newPenaltyRate the new penalty rate to be set
     * @notice This function allows the owner to set a new penalty rate for the loans.
     * The penalty rate is set as a percentage of the loan amount.
     * The penalty rate is multiplied by the PRECISION_FACTOR to handle decimal calculations.
     */
    function setPenaltyRate(uint256 _newPenaltyRate) external onlyOwner {
        s_penaltyRate = ((_newPenaltyRate * PRECISION_FACTOR) / 100);
    }

    /**
     * @param _newDaysGracePeriod the new grace period in days to be set
     * @notice This function allows the owner to set a new grace period for the loans.
     * The grace period is set in days and is used to determine the time allowed for payments.
     */
    function setdaysGracePeriod(
        uint256 _newDaysGracePeriod
    ) external onlyOwner {
        s_daysGracePeriod = _newDaysGracePeriod;
    }

    /**
     * @param borrower the address of the borrower
     * @notice This function allows the owner to set the borrower data.
     * It initializes the borrower's data if it does not already exist.
     * The borrower's score is set to 100.
     */
    function setBorrowerData(address borrower) internal onlyOwner {
        if (borrowerInfo[borrower].addressBorrower == address(0)) {
            borrowerInfo[borrower].addressBorrower = borrower;
            borrowerInfo[borrower].score = 100;
        }
    }

    /**
     * @param loanId the ID of the loan
     * @param rate the interest rate of the loan
     * @param typeInterest the type of interest (0 for simple, 1 for compound)
     * @param term the term of the loan in months
     * @param interval the interval of the loan (15 days or 30 days)
     * @param borrower the address of the borrower
     * @param amount amount to be lend
     * @notice this funtion set the data of the loan
     * The loan data is stored in the loanInfo mapping.
     * The function checks if the loan already exists and if the interval is valid.
     * If the loan does not exist, it initializes the loan data.
     */
    function setLoanData(
        uint256 loanId,
        uint256 rate,
        uint256 typeInterest,
        uint256 term,
        uint256 interval,
        address borrower,
        uint256 amount
    ) external onlyOwner {
        if (loanInfo[loanId].loanId != 0) {
            revert DebtRebaseToken__AlreadyExist(loanId);
        }
        if (interval != 15 days && interval != 30 days) {
            revert DebtRebaseToken__IntervalNotCorrect(interval);
        }
        setBorrowerData(borrower);
        loanInfo[loanId].loanId = loanId;
        loanInfo[loanId].rate = (rate * PRECISION_FACTOR) / 100;
        loanInfo[loanId].typeInterest = InterestType(typeInterest);
        loanInfo[loanId].endTime = block.timestamp + (term * interval);
        loanInfo[loanId].term = term;
        loanInfo[loanId].interval = interval;
        loanInfo[loanId].borrower = borrower;
        loanInfo[loanId].amount = amount;
        loanInfo[loanId].leftTerms = term;
        loanInfo[loanId].lastUpdateTime = block.timestamp;
        loanInfo[loanId].lastPayTime = block.timestamp;
        borrowerInfo[borrower].loanIds.push(loanId);
    }

    /**
     * @param loanId the ID of the loan
     * @param amount the amount to be minted
     * @notice This function allows the owner to mint new tokens for the borrower
     * which represent the debt in the protocol.
     */
    function mint(
        uint256 loanId,
        uint256 amount
    ) external onlyOwner loanExists(loanId) {
        address borrower = loanInfo[loanId].borrower;
        loanInfo[loanId].loanBalance += amount;
        borrowerInfo[borrower].totalLoanAmount += amount;
        _mint(borrower, amount);
    }

    /**
     * @param loanId the ID of the loan
     * @param amount the amount to be burned
     * @notice This function allows the owner to burn tokens from the borrower
     * which represent the user pain the debt in the protocol.
     */
    function burn(
        uint256 loanId,
        uint256 amount
    ) external onlyOwner loanExists(loanId) {
        address borrower = loanInfo[loanId].borrower;
        loanInfo[loanId].loanBalance -= amount;
        loanInfo[loanId].leftTerms--;
        loanInfo[loanId].lastUpdateTime = block.timestamp;
        loanInfo[loanId].lastPayTime = block.timestamp;
        borrowerInfo[borrower].totalPaidAmount += amount;
        _burn(borrower, amount);
        if (
            loanInfo[loanId].leftTerms == 0 || loanInfo[loanId].loanBalance == 0
        ) {
            delete loanInfo[loanId];
            emit CompletePaid(loanId, borrower, amount);
        }
    }

    /**
     * @param loanId the ID of the loan
     * @notice This function checks the state of the loan.
     * It checks if the loan has missed payments and applies penalties if necessary.
     * If the loan is liquidated, it burns the tokens and emits a liquidation event.
     * The function returns the state of the loan as an integer.
     * 0 = Ok
     * 1 = Missed penalty applied
     * 2 = Liquidated
     */
    function loanState(
        uint256 loanId
    ) external loanExists(loanId) returns (uint256) {
        if (checkLoanMisses(loanId)) {
            CleanLoan(loanId);
            return uint256(LoanState.Liquidated);
        } else {
            if (checkLoanPenalty(loanId)) {
                return uint256(LoanState.MissedPennaltyApplied);
            } else {
                return uint256(LoanState.Ok);
            }
        }
    }

    /**
     * @param loanId the ID of the loan
     * @notice This function cleans the loan data and burns the tokens.
     * It is called when the loan is liquidated.
     * The function emits a liquidation event.
     */
    function CleanLoan(uint256 loanId) internal {
        uint256 amount = loanInfo[loanId].loanBalance;
        _burn(loanInfo[loanId].borrower, amount);
        delete loanInfo[loanId];
        emit liquidate(loanId, loanInfo[loanId].borrower, amount);
    }

    /**
     * @param loanId the ID of the loan
     * @notice This function checks if the loan has missed payments.
     * It checks the time since the last payment and compares it to the interval and grace period.
     * If the time since the last payment is greater than the interval plus the grace period,
     * it checks if the loan has missed more than two payments.
     * If the loan has missed more than two payments, it returns true.
     * Otherwise, it returns false.
     */
    function checkLoanMisses(uint256 loanId) internal view returns (bool) {
        uint256 timeNoPayment = block.timestamp - loanInfo[loanId].lastPayTime;
        uint256 interval = loanInfo[loanId].interval;
        uint256 timePenalty = interval + s_daysGracePeriod;
        if (timeNoPayment > timePenalty) {
            if ((timeNoPayment - timePenalty) > (timePenalty * 2)) {
                return true;
            } else {
                return false;
            }
        }
    }

    /**
     * @param loanId the ID of the loan
     * @notice This function checks if the loan has penalties.
     */
    function checkLoanPenalty(uint256 loanId) internal returns (bool) {
        uint256 checkedBalance = balanceOfLoan(loanId);
        uint256 uncheckedBalance = loanInfo[loanId].loanBalance;
        if (checkedBalance > uncheckedBalance) {
            uint256 penalty = (checkedBalance - uncheckedBalance);
            loanInfo[loanId].penaltyAmount += penalty;
            borrowerInfo[loanInfo[loanId].borrower]
                .totalPenaltyAmount += penalty;
            borrowerInfo[loanInfo[loanId].borrower]
                .score -= POINTS_SCORE_PENALTY;
            loanInfo[loanId].loanBalance = checkedBalance;
            loanInfo[loanId].lastUpdateTime = block.timestamp;
            _mint(loanInfo[loanId].borrower, penalty);
            return true;
        } else {
            return false;
        }
    }

    /**
     * @param loanId the ID of the loan
     * @notice This function calculates the total amount to be paid for the loan.
     * It takes into account the loan amount, interest rate, type of interest,
     * and the remaining terms.
     */
    function amountPayTotal(
        uint256 loanId
    ) external view loanExists(loanId) returns (uint256) {
        uint256 loanAmount = balanceOfLoan(loanId);
        uint256 rate = loanInfo[loanId].rate;
        InterestType typeInterest = loanInfo[loanId].typeInterest;
        uint256 term = loanInfo[loanId].leftTerms;
        uint256 interval = loanInfo[loanId].interval;

        if (typeInterest == InterestType.Simple) {
            // Simple interest
            return
                loanAmount +
                interestLoanSimple(interval, rate, term, loanAmount);
        } else if (typeInterest == InterestType.Compound) {
            // Compound interest
            return interestLoanCompound(interval, rate, term, loanAmount);
        }
    }

    /**
     * @param loanId the ID of the loan
     * @notice This function calculates the amount to be paid each interval.
     * It takes into account the loan amount, interest rate, type of interest,
     * and the remaining terms.
     * The function returns the amount to be paid each interval.
     */
    function amountPayEachInterval(
        uint256 loanId
    ) external view loanExists(loanId) returns (uint256) {
        uint256 loanAmount = balanceOfLoan(loanId);
        uint256 rate = loanInfo[loanId].rate;
        InterestType typeInterest = loanInfo[loanId].typeInterest;
        uint256 leftTerms = loanInfo[loanId].leftTerms;
        uint256 interval = loanInfo[loanId].interval;

        if (typeInterest == InterestType.Simple) {
            // Simple interest
            return
                interestLoanSimple(interval, rate, leftTerms, loanAmount) /
                leftTerms;
        } else if (typeInterest == InterestType.Compound) {
            // Compound interest

            return
                interestLoanCompound(interval, rate, leftTerms, loanAmount) /
                leftTerms;
        }
    }

    /**
     * @param loanId the ID of the loan
     * @notice This function calculates the balance of the loan.
     * It takes into account the time since the last payment, the interval,
     * and the penalty rate.
     * The function returns the balance of the loan.
     * If the time since the last payment is greater than the interval plus the grace period,
     * it applies the penalty rate to the loan balance.
     */
    function balanceOfLoan(uint256 loanId) internal view returns (uint256) {
        uint256 timeNoPayment = block.timestamp -
            loanInfo[loanId].lastUpdateTime;
        uint256 interval = loanInfo[loanId].interval;
        uint256 amount = loanInfo[loanId].loanBalance;

        if (timeNoPayment > (interval + s_daysGracePeriod)) {
            uint256 ecu = (PRECISION_FACTOR + s_penaltyRate);
            for (
                uint96 i = 0;
                i <
                ((timeNoPayment - (interval + s_daysGracePeriod)) / 1 days) - 1;
                i++
            ) {
                ecu =
                    (ecu * (PRECISION_FACTOR + s_penaltyRate)) /
                    PRECISION_FACTOR;
            }
            return (amount * ecu) / PRECISION_FACTOR;
        } else {
            return (loanInfo[loanId].loanBalance);
        }
    }

    /**
     * @param loanId the ID of the loan
     * @notice This function calculates the total amount of the loan plus interest.
     * It takes into account the loan amount, interest rate, type of interest,
     * and the remaining terms.
     * The function returns the total amount of the loan plus interest.
     */
    function totalloanPlusInterest(
        uint256 loanId
    ) public view loanExists(loanId) returns (uint256) {
        uint256 amount = loanInfo[loanId].amount;
        uint256 rate = loanInfo[loanId].rate;
        InterestType typeInterest = loanInfo[loanId].typeInterest;
        uint256 term = loanInfo[loanId].term;
        uint256 interval = loanInfo[loanId].interval;

        if (typeInterest == InterestType.Simple) {
            // Simple interest
            return amount + interestLoanSimple(interval, rate, term, amount);
        } else if (typeInterest == InterestType.Compound) {
            // Compound interest
            return interestLoanCompound(interval, rate, term, amount);
        }
    }

    /**
     * @param interval the interval of the loan (15 days or 30 days)
     * @param rate the interest rate of the loan
     * @param term the term of the loan in months
     * @param amount the amount of the loan
     * @notice This function calculates the interest for a simple loan.
     * It takes into account the interval, interest rate, term, and amount.
     * The function returns the interest amount.
     */
    function interestLoanSimple(
        uint256 interval,
        uint256 rate,
        uint256 term,
        uint256 amount
    ) internal pure returns (uint256) {
        if (interval == 15 days) {
            return (amount * (rate / 24)) * term;
        } else {
            return (amount * (rate / 12)) * term;
        }
    }

    /**
     * @param interval the interval of the loan (15 days or 30 days)
     * @param rate the interest rate of the loan
     * @param term the term of the loan in months
     * @param amount the amount of the loan
     * @notice This function calculates the interest for a compound loan.
     * It takes into account the interval, interest rate, term, and amount.
     * The function returns the interest amount.
     */
    function interestLoanCompound(
        uint256 interval,
        uint256 rate,
        uint256 term,
        uint256 amount
    ) internal pure returns (uint256) {
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

        // Final amount = principal * compound factor
        return (amount * factor) / PRECISION_FACTOR;
    }

    /**
     * @param borrower the address of the borrower
     * @notice This function calculates the total balance of the borrower.
     */
    function balanceOf(
        address borrower
    ) public view virtual override returns (uint256) {
        uint256 totalDebtLoanAmount;
        uint256 numberOfLoans = borrowerInfo[borrower].loanIds.length;
        for (uint256 i = 0; i < numberOfLoans; i++) {
            uint256 loanId = borrowerInfo[borrower].loanIds[i];
            totalDebtLoanAmount += balanceOfLoan(loanId);
        }
        return (totalDebtLoanAmount);
    }

    /**
     * @dev transfer function is not allowed in this contract.
     */
    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        revert DebtRebaseToken__TranferNotAllowed();
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        revert DebtRebaseToken__TranferNotAllowed();
        return true;
    }

    // --- Getters ---------
    function getLoanInfo(
        uint256 loanId
    ) external view returns (loanData memory) {
        return loanInfo[loanId];
    }

    function getBorrowerInfo(
        address borrower
    ) external view returns (borrowerData memory) {
        return borrowerInfo[borrower];
    }

    function getLeftTerm(uint256 loanId) external view returns (uint256) {
        return loanInfo[loanId].leftTerms;
    }

    function getBalanceLoanMinted(
        uint256 loanId
    ) external view returns (uint256) {
        return loanInfo[loanId].loanBalance;
    }

    function getTotalPenaltyLoan(
        uint256 loanId
    ) external view returns (uint256) {
        return loanInfo[loanId].penaltyAmount;
    }

    function gettotalloanPlusInterest(
        uint256 loanId
    ) external view returns (uint256) {
        return totalloanPlusInterest(loanId);
    }

    function getPenaltyRate() external view returns (uint256) {
        return s_penaltyRate;
    }

    function getDaysGracePeriod() external view returns (uint256) {
        return s_daysGracePeriod;
    }

    function getPrecisionFactor() external pure returns (uint256) {
        return PRECISION_FACTOR;
    }

    function getPointsScorePenalty() external pure returns (uint256) {
        return POINTS_SCORE_PENALTY;
    }

    function getBalaceOfLoan(uint256 loanId) external view returns (uint256) {
        return balanceOfLoan(loanId);
    }
}
