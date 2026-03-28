// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.2;

import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol"

library Structs {
  struct LoanPair {
    IERC20 lendingAsset;
    IERC20 collateralAsset;
    uint256 lendingAmount;
    uint256 collateralAmount;
    uint256 loanDuration;
    uint256 interestRate;
  }

  struct Lender {
    address lenderAddress;
    LoanPair[] loanPairs;
  }
}