# NFT Vault Loan Protocol

This project is a smart contract system built in Solidity using Foundry. It allows users to obtain loans by using NFTs as collateral. Lenders can provide capital to earn interest over time, which is managed using a Rebase token model.

## 🚀 Features

- Borrow against NFTs as collateral
- Fixed interest rate and loan term
- Rebase token interest accrual
- Payment interval tracking
- Secure loan liquidations for overdue payments

## 🛠️ Built With

- [Solidity](https://soliditylang.org/)
- [Foundry](https://book.getfoundry.sh/) for development and testing
- [OpenZeppelin](https://docs.openzeppelin.com/) for standard contracts and utilities

## 📦 Contracts

### Vault.sol

Main contract managing:
- NFT deposits
- Loan offers and acceptance
- Loan term tracking
- Interest payments using Rebase tokens
- Liquidations

## 🧠 How It Works

1. **Borrowers** deposit an NFT into the Vault.
2. **Lenders** offer loan terms: amount, duration, interest rate.
3. **Borrowers** accept offers.
4. Loan accrues interest via Rebase token mechanism.
5. If loan is repaid on time, NFT is returned.
6. If not repaid, NFT is liquidated to the lender.

## 🔐 Security Considerations

- Only whitelisted NFT collections can be used as collateral.
- Interest is calculated and tracked on a per-loan basis.
- Uses non-reentrancy guards and access controls where appropriate.

## 🧪 Testing

Run tests using Foundry:

```bash
forge test

