// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Structs, Errors } from "../types/Types.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract LoanVault is Ownable{
  IERC20 lendingAsset;
  IERC20 collateralAsset;
  uint256 collateralAmount; // On a scale of 1 - 100; therefore, 100 means 100%
  mapping(address borrower => uint256 amountBorrowed) private borrowers;

  constructor(IERC20 _lendingAsset, IERC20 _collateralAsset) Ownable(msg.sender) {
    lendingAsset = _lendingAsset;
    collateralAsset = _collateralAsset;
  }

  function addLiquidity(uint256 _amount) external onlyOwner {
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    lendingAsset.transferFrom(msg.sender, address(this), _amount);
  }

  function removeLiquidity(uint256 _amount) external onlyOwner {
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    lendingAsset.transfer(msg.sender, _amount);
  }

  function borrow(address msg.sender, uint256 _amount) external {
    if (borrowers[msg.sender] > 0) revert Errors.LoanVault__HasOutstandingLoan(borrowers[msg.sender]);
    if (msg.sender == address(0)) revert Errors.LoanVault__ZeroAddress();
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();
    if (lendingAsset.balanceOf(address(this)) < _amount) revert Errors.LoanVault__InsufficientLoanVaultBalance();
    if (collateralAsset.balanceOf(msg.sender)  < (_amount + _getCollateralAmountForLoan(_amount))) revert Errors.LoanVault__InsufficientBorrowerCollateralBalance();

    borrowers[msg.sender] = _amount;
  }

  function _getCollateralAmountForLoan(uint256 _loanAmount) private view returns (uint256) {
    return (_loanAmount * collateralAmount) / 100;
  }

  function getLendingAsset() external view returns (address) {
    return address(lendingAsset);
  }

  function getCollateralAsset() external view returns (address) {
    return address(collateralAsset);
  }

  function getLendingAssetBalance() external view returns (uint256) {
    return lendingAsset.balanceOf(address(this));
  }

  function getCollateralAssetBalance() external view returns (uint256) {
    return collateralAsset.balanceOf(address(this));
  }
}