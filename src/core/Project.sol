// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Structs, Errors } from "../types/Types.sol";
import { LoanVault } from "./LoanVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Project is Ownable(msg.sender) {
  mapping(address lender => Structs.Lender lenderDetails) private lendersDetail;

  modifier onlyLender() {
    if (!_isLender(msg.sender)) revert Errors.Project__NotALender();
    _;
  }

  function registerAsLender() public {
    if (_isLender(msg.sender)) revert Errors.Project__IsAlreadyALender();

    Structs.Lender memory lender;
    lender.lenderAddress = msg.sender;
    lender.joinedAt = block.timestamp;

    lendersDetail[msg.sender] = lender;
  }

  function createLoanVault(IERC20 _lendingAsset, IERC20 _collateralAsset, uint256 _collateralRate, uint256 _duration) external onlyLender {
    Structs.Lender storage lender = lendersDetail[msg.sender];

    LoanVault loanVault = new LoanVault(_lendingAsset, _collateralAsset, _collateralRate, _duration);

    lender.loanVaults.push(loanVault);
  }

  function _isLender(address lender) private view returns (bool) {
    return lendersDetail[lender].lenderAddress == lender;
  }

  function isLender(address lender) external view returns (bool) {
    return _isLender(lender);
  }
}