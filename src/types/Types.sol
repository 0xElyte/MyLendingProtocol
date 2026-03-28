// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.2;

import { LoanVault } from "../core/LoanVault.sol";

library Structs {
  struct Lender {
    address lenderAddress;
    uint256 joinedAt;
    LoanVault[] loanVaults;
  }
}

library Errors {
  error Project__IsAlreadyALender();
  error LoanVault__ZeroAmount();
  error LoanVault__ZeroAddress();
  error LoanVault__InsufficientLoanVaultBalance();
  error LoanVault__InsufficientBorrowerCollateralBalance();
  error LoanVault__HasOutstandingLoan(uint256 amount);
}