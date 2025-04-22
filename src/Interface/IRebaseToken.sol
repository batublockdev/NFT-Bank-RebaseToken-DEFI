//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IRebaseToken {
    function setLoanData(
        uint256 loanId,
        uint256 rate,
        uint256 typeInterest,
        uint256 term,
        uint256 interval,
        address borrower,
        uint256 amount
    ) external;

    function mint(uint256 loanId, uint256 amount) external;

    function burn(uint256 loanId, uint256 amount) external;

    function loanState(uint256 loanId) external returns (uint256);

    function amountPayTotal(uint256 loanId) external view returns (uint256);

    function amountPayEachInterval(
        uint256 loanId
    ) external view returns (uint256);

    function getBalaceOfLoan(uint256 loanId) external view returns (uint256);

    function getTotalPenaltyLoan(
        uint256 loanId
    ) external view returns (uint256);

    function gettotalloanPlusInterest(
        uint256 loanId
    ) external view returns (uint256);

    function getLeftTerm(uint256 loanId) external view returns (uint256);

    function getBalanceLoanMinted(
        uint256 loanId
    ) external view returns (uint256);

    function getTotalInterest(uint256 loanId) external view returns (uint256);
}
