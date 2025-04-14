//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//// ---IMPORTS ---/////////

/**
 * @title Vault
 * @author batublockdev
 * @notice this contract is used to connect the lenders with borrowers
 * listing the nfts that are going to be used as collateral
 */

contract Vault {
    function requestLoan(
        uint256 rate,
        uint256 typeInterest,
        uint256 term,
        uint256 interval,
        uint256 amount,
        address token,
        address addressNft,
        uint256 nftId
    ) public {
        // Logic to request a loan
    }

    function offerLoan() public {
        // Logic to offer a loan
    }

    function approveLoan() public {
        // Logic to approve a loan
    }

    function payLoan() public {
        // Logic to pay a loan
    }

    function payLoanTotal() public {
        // Logic to pay the total loan
    }

    function liquidateLoan() public {
        // Logic to liquidate a loan
    }
}
