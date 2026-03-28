// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.2;

import { LoanVault } from "../core/LoanVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Structs {
  struct Lender {
    address lenderAddress;
    uint256 joinedAt;
    mapping(address lendingAsset => LoanVault vault) loanVaults;
  }

  struct Borrower {
    address borrowerAddress;
    address lenderAddress;
    IERC20 loanAsset; // collateral asset
    IERC20 debtAsset; // asset borrowed
    uint256 amountBorrowed;
    uint256 amountToRepay;
    uint256 penaltyFeeAccrued;
    uint256 amountColateralDropped;
    uint256 borrowedAt;
    uint256 dueTime;
  }
}

library Errors {
  // Project Errors
  error Project__IsAlreadyALender();
  error Project__NotALender();

  // Loan Vault Errors
  error LoanVault__ZeroAmount();
  error LoanVault__ZeroAddress();
  error LoanVault__InsufficientLoanVaultBalance();
  error LoanVault__InsufficientBorrowerCollateralBalance();
  error LoanVault__HasOutstandingLoan(uint256 amount);
  error LoanVault__NoOutstandingLoan();
}