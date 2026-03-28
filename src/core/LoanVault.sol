// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Structs, Errors } from "../types/Types.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract LoanVault is Ownable{
  IERC20 lendingAsset;
  IERC20 collateralAsset;
  uint256 collateralRate; // On a scale of 1 - 100; therefore, 100 means 100%
  uint256 duration;
  mapping(address borrower => Structs.Borrower) private borrowers;

  constructor(IERC20 _lendingAsset, IERC20 _collateralAsset, uint256 _collateralRate, uint256 _duration) Ownable(msg.sender) {
    lendingAsset = _lendingAsset;
    collateralAsset = _collateralAsset;
    collateralRate = _collateralRate;
    duration = _duration;
  }

  function addLiquidity(uint256 _amount) external onlyOwner {
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    require(lendingAsset.transferFrom(msg.sender, address(this), _amount));
  }

  function removeLiquidityLending(uint256 _amount) external onlyOwner {
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

  // ToDo: Collect Protocol Fee
    require(lendingAsset.transfer(msg.sender, _amount));
  }
  
  function withdrawCollateral(uint256 _amount) external onlyOwner {
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    // ToDo: Collect Protocol Fee

    require(collateralAsset.transfer(msg.sender, _amount));
  }

  function borrow(uint256 _amount) external {
    Structs.Borrower storage borrower = borrowers[msg.sender];
    if (_isBorrower(msg.sender)) revert Errors.LoanVault__HasOutstandingLoan(borrower.amountBorrowed);

    if (borrower.borrowerAddress == address(0)) revert Errors.LoanVault__ZeroAddress();
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();
    if (lendingAsset.balanceOf(address(this)) < _amount) revert Errors.LoanVault__InsufficientLoanVaultBalance();
    
    uint256 collateralAmount = _getTotalCollateralForLoan(_amount);
    if (collateralAsset.balanceOf(borrower.borrowerAddress)  < collateralAmount) revert Errors.LoanVault__InsufficientBorrowerCollateralBalance();

    borrower.lenderAddress = owner();
    borrower.loanAsset = lendingAsset;
    borrower.debtAsset = collateralAsset;
    borrower.amountBorrowed = _amount;
    borrower.amountColateralDropped = collateralAmount;
    borrower.dueTime = block.timestamp + duration;

    bool success = collateralAsset.transferFrom(borrower.borrowerAddress, address(this), collateralAmount);

    require(success);

    require(lendingAsset.transfer(borrower.borrowerAddress, _amount));
  }

  function _getTotalCollateralForLoan(uint256 _loanAmount) private view returns (uint256) {
    return _loanAmount +  _getCollateralAmountForLoan(_loanAmount);
  }

  function getTotalCollateralForLoan(uint256 _loanAmount) external view returns (uint256) {
    return _getTotalCollateralForLoan(_loanAmount);
  }


  function _getCollateralAmountForLoan(uint256 _loanAmount) private view returns (uint256) {
    return (_loanAmount * collateralRate) / 100;
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

  function _getCollateralAssetBalance() private view returns (uint256) {
    return collateralAsset.balanceOf(address(this));
  }

  function getCollateralAssetBalance() external view returns (uint256) {
    return _getCollateralAssetBalance();
  }

  function _isBorrower(address _borrower) private view returns (bool) {
    return borrowers[_borrower].amountBorrowed > 0;
  }
  
  function isBorrower(address _borrower) external view returns (bool) {
    return _isBorrower(_borrower);
  }

  function getVaultAddress() external view returns (address) {
    return address(this);
  }
}