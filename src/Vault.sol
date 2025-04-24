//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//// ---IMPORTS ---/////////
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./Interface/IRebaseToken.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title Vault
 * @author batublockdev
 * @notice this contract is used to connect the lenders with borrowers
 * listing the nfts that are going to be used as collateral
 */

contract Vault is IERC721Receiver {
    // Custom errors
    error Vault__NotOwnerOfNFT(address addressNft, uint256 nftId);
    error Vault__NotApprovedForNFT(address addressNft, uint256 nftId);
    error Vault__TypeInterestNotValid(uint256 typeInterest);
    error Vault__IntervalNotValid(uint256 interval);
    error Vault__RateNotValid(uint256 rate);
    error Vault__TermNotValid(uint256 term);
    error Vault__AmountNotValid(uint256 amount);
    error Vault__TokenNotValid(address token);
    error Vault__NotApprovedForToken(address token);
    error Vault__FaildReceiveToken(address token);
    error Vault__loanNotFound(uint256 loanId);
    error Vault__loanOfferNotFound(uint256 offerId);
    error Vault__NotOwnerOfLoan(address borrower);
    error Vault__FaildSendToken(address token);
    error Vault__NotCeo();
    error Vault__BalanceTokenCero();

    // Struct to hold loan details
    struct RequestLoan {
        uint256 loanId; // Loan ID
        address borrower; // Borrower address
        uint256 rate; // Interest rate
        uint256 typeInterest; // Type of interest (Simple or compound)
        uint256 term; // Loan term in days
        uint256 interval; // Payment interval in days
        uint256 amount; // Loan amount
        address token; // Token address for payment
        address addressNft; // NFT contract address
        uint256 nftId; // NFT ID
        LoanOffer[] offers; // Loan offer details
    }
    struct Loan {
        uint256 loanId; // Loan ID
        address borrower; // Borrower address
        address lender; // Lender address
        uint256 rate; // Interest rate
        uint256 typeInterest; // Type of interest (Simple or compound)
        uint256 term; // Loan term in days
        uint256 interval; // Payment interval in days
        uint256 amount; // Loan amount
        address token; // Token address for payment
        address addressNft; // NFT contract address
        uint256 nftId; // NFT ID
    }
    struct LoanOffer {
        uint256 offerId; // Offer ID
        uint256 loanId; // Loan ID
        address lender; // Lender address
        address token; // Token address for payment
        uint256 amount; // Loan amount
        uint256 rate; // Interest rate
        uint256 typeInterest; // Type of interest (Simple or compound)
        uint256 term; // Loan term in days
        uint256 interval; // Payment interval in days
    }
    // Mapping to store loans
    mapping(uint256 loanId => RequestLoan) public requestloans;
    // Mapping to store loan offers
    mapping(uint256 offerId => LoanOffer) public loanOffers;
    /// Mapping to store approved loans
    mapping(uint256 loanId => Loan) public approvedLoans;
    mapping(address token => uint256 balance) public feed_balances;

    // Array to store loan IDs
    // Array to store offer IDs
    // Array to store approved loan IDs
    uint256[] public loanIds;
    uint256[] public offerIds;
    uint256[] public approvedLoanIds;
    address private s_ceo;

    //---- Modifiers ----//
    modifier checkNft(
        address addressNft,
        uint256 nftId,
        address borrower
    ) {
        if (IERC721(addressNft).ownerOf(nftId) != borrower) {
            revert Vault__NotOwnerOfNFT(addressNft, nftId);
        }
        if (IERC721(addressNft).getApproved(nftId) != address(this)) {
            revert Vault__NotApprovedForNFT(addressNft, nftId);
        }
        if (IERC721(addressNft).isApprovedForAll(borrower, address(this))) {
            revert Vault__NotApprovedForNFT(addressNft, nftId);
        }
        _;
    }
    modifier loanRequestExists(uint256 loanId) {
        if (requestloans[loanId].loanId == 0) {
            revert Vault__loanNotFound(loanId);
        }
        _;
    }
    modifier loanExists(uint256 loanId) {
        if (approvedLoans[loanId].loanId == 0) {
            revert Vault__loanNotFound(loanId);
        }
        _;
    }
    modifier tokenCheck(
        address token,
        address from,
        uint256 amount
    ) {
        if (token == address(0)) {
            revert Vault__TokenNotValid(token);
        }
        if (IERC20(token).allowance(from, address(this)) < amount) {
            revert Vault__NotApprovedForToken(token);
        }
        _;
    }

    modifier checkDataInput(uint256 typeInterest, uint256 interval) {
        if (typeInterest != 0 && typeInterest != 1) {
            revert Vault__TypeInterestNotValid(typeInterest);
        }
        if (interval != 0 && interval != 1) {
            revert Vault__IntervalNotValid(interval);
        }
        _;
    }

    IRebaseToken private immutable i_rebaseToken;

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
        s_ceo = msg.sender;
    }

    /**
     *
     * @param rate the interest rate ( (0) to let the lender set the rate)
     * @param typeInterest the type of interest (0 = simple, 1 = compound)
     * @param term the term of the loan in intervals (15 or 30 days)
     * @param interval the interval of the loan (0 = 15 days, 1 = mounthly)
     * @param amount the amount of the loan ((0) to let the lender set the amount)
     * @param token the token address from the currency that is expected
     * to accept the loan ((0) to let the lender set the token)
     * @param addressNft the address of the nft contract
     * @param nftId the id of the nft
     * @notice this function is used to request a loan the borrower
     * provides the details of the loan and the nft that is going to be used as collateral
     * @dev this function checks if the borrower is the owner of the nft and if the nft is approved for the contract
     */
    function requestLoan(
        uint256 rate,
        uint256 typeInterest,
        uint256 term,
        uint256 interval,
        uint256 amount,
        address token,
        address addressNft,
        uint256 nftId
    )
        public
        checkNft(addressNft, nftId, msg.sender)
        checkDataInput(typeInterest, interval)
    {
        if (interval == 0) {
            interval = 15 days;
        } else {
            interval = 30 days;
        }

        // Logic to request a loan
        // Create a new loan
        uint256 loanId = uint256(
            keccak256(abi.encodePacked(msg.sender, block.timestamp))
        );
        loanIds.push(loanId);
        requestloans[loanId] = RequestLoan({
            loanId: loanId,
            borrower: msg.sender,
            rate: rate,
            typeInterest: typeInterest,
            term: term,
            interval: interval,
            amount: amount,
            token: token,
            addressNft: addressNft,
            nftId: nftId,
            offers: new LoanOffer[](0)
        });

        // Emit an event for the loan request
        // emit LoanRequested(loanId, msg.sender, rate, typeInterest, term, interval, amount, token, addressNft, nftId);
    }

    /**
     * @param loanId the id of the loan
     * @param amount the amount of the loan
     * @param rate the interest rate
     * @param typeInterest the type of interest (0 = simple, 1 = compound)
     * @param term the term of the loan in intervals (15 or 30 days)
     * @param interval the interval of the loan (0 = 15 days, 1 = mounthly)
     * @param token the token address from the currency that is expected
     * to accept the loan
     * @notice this function is used to offer a loan to a borrower
     * @dev this function checks if the loan exists and if the lender has approved the contract to spend the tokens
     */
    function offerLoan(
        uint256 loanId,
        uint256 amount,
        uint256 rate,
        uint256 typeInterest,
        uint256 term,
        uint256 interval,
        address token
    )
        public
        tokenCheck(token, msg.sender, amount)
        loanRequestExists(loanId)
        checkDataInput(typeInterest, interval)
    {
        if (rate == 0 || rate > 100) {
            revert Vault__RateNotValid(rate);
        }
        if (term == 0 || term > 24) {
            revert Vault__TermNotValid(term);
        }
        if (amount == 0) {
            revert Vault__AmountNotValid(amount);
        }

        if (interval == 0) {
            interval = 15 days;
        } else {
            interval = 30 days;
        }
        // Logic to offer a loan

        // Create a new loan offer
        uint256 offerId = uint256(
            keccak256(abi.encodePacked(msg.sender, block.timestamp))
        );
        offerIds.push(offerId);
        loanOffers[offerId] = LoanOffer({
            offerId: offerId,
            loanId: loanId,
            lender: msg.sender,
            amount: amount,
            token: token,
            rate: rate,
            typeInterest: typeInterest,
            term: term,
            interval: interval
        });
        // Add the offer to the loan
        requestloans[loanId].offers.push(loanOffers[offerId]);
        // Emit an event for the loan offer
        // emit LoanOffered(offerId, loanId, msg.sender, amount, rate, typeInterest, term, interval, token);
    }

    function approveLoan(
        uint256 loanId,
        uint256 offerId
    )
        public
        loanRequestExists(loanId)
        checkNft(
            requestloans[loanId].addressNft,
            requestloans[loanId].nftId,
            requestloans[loanId].borrower
        )
        tokenCheck(
            loanOffers[offerId].token,
            loanOffers[offerId].lender,
            loanOffers[offerId].amount
        )
    {
        if (loanOffers[offerId].loanId == 0) {
            revert Vault__loanOfferNotFound(offerId);
        }
        if (loanOffers[offerId].loanId != loanId) {
            revert Vault__loanOfferNotFound(offerId);
        }
        if (requestloans[loanId].borrower != msg.sender) {
            revert Vault__NotOwnerOfLoan(requestloans[loanId].borrower);
        }
        // Logic to approve a loan
        // Transfer the NFT to the contract
        IERC721(requestloans[loanId].addressNft).safeTransferFrom(
            msg.sender,
            address(this),
            requestloans[loanId].nftId
        );
        // Transfer the tokens to borrower
        //check amount
        if (
            IERC20(loanOffers[offerId].token).transferFrom(
                loanOffers[offerId].lender,
                requestloans[loanId].borrower,
                loanOffers[offerId].amount
            ) == false
        ) {
            revert Vault__FaildReceiveToken(loanOffers[offerId].token);
        }
        //create a loan data
        approvedLoans[loanId] = Loan({
            loanId: loanId,
            borrower: requestloans[loanId].borrower,
            lender: loanOffers[offerId].lender,
            rate: loanOffers[offerId].rate,
            typeInterest: loanOffers[offerId].typeInterest,
            term: loanOffers[offerId].term,
            interval: loanOffers[offerId].interval,
            amount: loanOffers[offerId].amount,
            token: loanOffers[offerId].token,
            addressNft: requestloans[loanId].addressNft,
            nftId: requestloans[loanId].nftId
        });
        approvedLoanIds.push(loanId);
        i_rebaseToken.setLoanData(
            loanId,
            loanOffers[offerId].rate,
            loanOffers[offerId].typeInterest,
            loanOffers[offerId].term,
            loanOffers[offerId].interval,
            requestloans[loanId].borrower,
            loanOffers[offerId].amount
        );
        i_rebaseToken.mint(loanId, loanOffers[offerId].amount);
        delete loanOffers[offerId];
        // Emit an event for the loan approval
        // emit LoanApproved(loanId, offerId, msg.sender, loanOffers[offerId].lender, amount, rate, typeInterest, term, interval, token);
        delete requestloans[loanId];
    }

    /**
     * @param loanId the id of the loan
     * @notice this function is used to pay the loan
     * @dev this function checks if the loan exists
     * and if the borrower has approved the contract to spend the tokens
     * the protocol charges a fee of 3% of the interests earned
     */
    function payLoan(uint256 loanId) public loanExists(loanId) {
        uint256 state = i_rebaseToken.loanState(loanId);
        if (state == 2) {
            liquidateLoan(loanId, approvedLoans[loanId].lender);
        } else {
            uint256 penalty;
            uint256 amountPay = i_rebaseToken.amountPayEachInterval(loanId);
            if (
                !IERC20(approvedLoans[loanId].token).transferFrom(
                    msg.sender,
                    address(this),
                    amountPay
                )
            ) {
                revert Vault__FaildReceiveToken(approvedLoans[loanId].token);
            }
            if (i_rebaseToken.getTotalPenaltyLoan(loanId) == 0) {
                penalty = 0;
            } else {
                penalty = i_rebaseToken.getTotalPenaltyLoan(loanId);
            }

            uint256 interest = i_rebaseToken.getTotalInterest(loanId);

            uint256 penaltyAmount = penalty / approvedLoans[loanId].term;

            uint256 interestPerInterval = interest / approvedLoans[loanId].term;

            uint256 protocolFee = ((interestPerInterval + penaltyAmount) * 3) /
                100;
            feed_balances[approvedLoans[loanId].token] += protocolFee;
            i_rebaseToken.burn(loanId, amountPay - interestPerInterval);
            if (
                IERC20(approvedLoans[loanId].token).transfer(
                    approvedLoans[loanId].lender,
                    amountPay - protocolFee
                ) == false
            ) {
                revert Vault__FaildSendToken(approvedLoans[loanId].token);
            }
            if (
                i_rebaseToken.getBalanceLoanMinted(loanId) == 0 ||
                i_rebaseToken.getLeftTerm(loanId) == 0
            ) {
                liquidateLoan(loanId, approvedLoans[loanId].borrower);
            }
        }
    }

    /**
     *
     * @param loanId the id of the loan
     * @notice this function is used to pay the total amount of the loan
     * @dev this function checks if the loan exists
     * the protocol charges a fee of 3% of the total amount
     */
    function payLoanTotal(uint256 loanId) public loanExists(loanId) {
        uint256 state = i_rebaseToken.loanState(loanId);
        if (state == 2) {
            liquidateLoan(loanId, approvedLoans[loanId].lender);
        } else {
            uint256 amountPayPlusInterest = i_rebaseToken.amountPayTotal(
                loanId
            );
            uint256 amountNoInterest = i_rebaseToken.getBalaceOfLoan(loanId);

            if (
                !IERC20(approvedLoans[loanId].token).transferFrom(
                    msg.sender,
                    address(this),
                    amountPayPlusInterest
                )
            ) {
                revert Vault__FaildReceiveToken(approvedLoans[loanId].token);
            }
            uint256 protocolFee = ((amountPayPlusInterest - amountNoInterest) *
                3) / 100;
            feed_balances[approvedLoans[loanId].token] += protocolFee;
            i_rebaseToken.burn(loanId, amountNoInterest);
            if (
                IERC20(approvedLoans[loanId].token).transfer(
                    approvedLoans[loanId].lender,
                    amountPayPlusInterest - protocolFee
                ) == false
            ) {
                revert Vault__FaildSendToken(approvedLoans[loanId].token);
            }
            if (
                i_rebaseToken.getBalanceLoanMinted(loanId) == 0 ||
                i_rebaseToken.getLeftTerm(loanId) == 0
            ) {
                liquidateLoan(loanId, approvedLoans[loanId].borrower);
            }
        }
    }

    /**
     * @param loanId the id of the loan
     * @notice this function is used to update the state of the loan
     */
    function updateLoanState(uint256 loanId) public loanExists(loanId) {
        uint256 state = i_rebaseToken.loanState(loanId);
        if (state == 2) {
            liquidateLoan(loanId, approvedLoans[loanId].lender);
        }
    }

    /**
     * @param loanId the id of the loan
     * @param who the address to send the nft either can be the borrower or lender
     */
    function liquidateLoan(uint256 loanId, address who) internal {
        if (approvedLoans[loanId].loanId == 0) {
            revert Vault__loanNotFound(loanId);
        }

        // Logic to liquidate a loan
        // Transfer the NFT back to the borrower
        IERC721(approvedLoans[loanId].addressNft).safeTransferFrom(
            address(this),
            who,
            approvedLoans[loanId].nftId
        );
        delete approvedLoans[loanId];
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdrawFee(address who, address token) external {
        if (msg.sender != s_ceo) {
            revert Vault__NotCeo();
        }
        if (feed_balances[token] == 0) {
            revert Vault__BalanceTokenCero();
        }
        if (IERC20(token).transfer(who, feed_balances[token]) == false) {
            revert Vault__FaildSendToken(token);
        }
    }

    function ceo() external view returns (address) {
        return s_ceo;
    }
}
