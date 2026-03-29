// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Structs, Errors } from "../types/Types.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Project } from "./Project.sol";

contract LoanVault is Ownable, ReentrancyGuard {
  Project immutable iProject;
  IERC20 private lendingAsset;
  IERC20 private collateralAsset;
  uint256 private collateralRate; // On a scale of 1 - 100; therefore, 100 means 100%
  uint256 private interestRate; // On a scale of 1 - 100; therefore, 100 means 100%
  uint256 private penaltyRatePerDay; // On a scale of 1 - 100; therefore, 100 means 100%
  uint256 private duration;
  mapping(address borrower => Structs.Borrower) private borrowers;

  constructor(address _iProject, address _owner, IERC20 _lendingAsset, IERC20 _collateralAsset, uint256 _collateralRate, uint256 _interestRate, uint256 _penaltyRatePerDay, uint256 _duration) Ownable(_owner) {
    iProject = Project(_iProject);
    lendingAsset = _lendingAsset;
    collateralAsset = _collateralAsset;
    collateralRate = _collateralRate;
    interestRate = _interestRate;
    penaltyRatePerDay = _penaltyRatePerDay;
    duration = _duration;
  }

  function addLiquidity(uint256 _amount) external onlyOwner {
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    require(lendingAsset.transferFrom(msg.sender, address(this), _amount));
  }

  function removeLiquidityLending(uint256 _amount) external onlyOwner nonReentrant {
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    uint256 protocolAmount = (_amount * iProject.getProtocolFee()) / (100 * 10 ** iProject.PROTOCOL_FEE_DECIMAL_POINT());
    
    require(lendingAsset.transfer(address(iProject), protocolAmount));

    require(lendingAsset.transfer(msg.sender, _amount - protocolAmount));
  }
  
  function withdrawCollateral(uint256 _amount) external onlyOwner nonReentrant {
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    uint256 protocolAmount =  (_amount * iProject.getProtocolFee()) / (100 * 10 ** iProject.PROTOCOL_FEE_DECIMAL_POINT());
    require(collateralAsset.transfer(address(iProject), protocolAmount));

    require(collateralAsset.transfer(msg.sender, _amount));
  }

  function borrow(uint256 _amount) external nonReentrant returns (bool) {
    if (msg.sender == address(0)) revert Errors.LoanVault__ZeroAddress();
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    if (_isBorrower(msg.sender)) revert Errors.LoanVault__HasOutstandingLoan(borrowers[msg.sender].amountBorrowed);
    if (lendingAsset.balanceOf(address(this)) < _amount) revert Errors.LoanVault__InsufficientLoanVaultBalance();
    
    uint256 collateralAmount = _getTotalCollateralForLoan(_amount);
    if (collateralAsset.balanceOf(msg.sender)  < collateralAmount) revert Errors.LoanVault__InsufficientBorrowerCollateralBalance();

    Structs.Borrower storage borrower = borrowers[msg.sender];

    borrower.borrowedAt = block.timestamp;
    borrower.dueTime = block.timestamp + duration;
    borrower.borrowerAddress = msg.sender;
    borrower.lenderAddress = owner();
    borrower.loanAsset = lendingAsset;
    borrower.debtAsset = collateralAsset;
    borrower.amountBorrowed = _amount;
    borrower.amountColateralDropped = collateralAmount;
    borrower.amountToRepay = _amount + _calculateInterest(_amount);

    bool success = collateralAsset.transferFrom(msg.sender,  address(this), collateralAmount);

    require(success);

    require(lendingAsset.transfer(borrower.borrowerAddress, _amount));
    
    return true;
  }

  function repay(uint256 _amount) external nonReentrant returns (bool) {
    if (!_isBorrower(msg.sender)) revert Errors.LoanVault__NoOutstandingLoan();
    if (_amount == 0) revert Errors.LoanVault__ZeroAmount();

    Structs.Borrower storage borrower = borrowers[msg.sender];
    uint256 _amountToRepay = borrower.amountToRepay;

    if (block.timestamp > borrower.dueTime) {
      uint256 _overdueTime = block.timestamp - borrower.dueTime;
      
      borrower.penaltyFeeAccrued = _calculatePenalty(_amountToRepay, _overdueTime);
    }

    uint256 _netAmountToRepay = borrower.amountToRepay + borrower.penaltyFeeAccrued;
    borrower.amountToRepay = _netAmountToRepay;
    
    uint256 amountRepayingNow;

    if (_amount > _netAmountToRepay) {
      amountRepayingNow = _amount - _netAmountToRepay;
    }
    else {
      amountRepayingNow = _amount;
    }

    (bool success ) = lendingAsset.transferFrom(msg.sender, address(this), amountRepayingNow);

    require (success);

    borrower.amountToRepay -= amountRepayingNow;

    if (borrower.amountToRepay == 0) {
      (bool collateralTransferSuccess) = collateralAsset.transfer(msg.sender, borrower.amountColateralDropped);

      require(collateralTransferSuccess);

      borrower.lenderAddress = address(0);
      borrower.loanAsset = IERC20(address(0));
      borrower.debtAsset = IERC20(address(0));
      borrower.amountBorrowed = 0;
      borrower.amountToRepay = 0;
      borrower.penaltyFeeAccrued = 0;
      borrower.amountColateralDropped = 0;
      borrower.borrowedAt = 0;
      borrower.dueTime = 0;
    }

    return true;
  }

  function editCollateralRate(uint256 _newRate) external onlyOwner {
    collateralRate = _newRate;
  }

  function editInterestRate(uint256 _newRate) external onlyOwner {
    interestRate = _newRate;
  }

  function editPenaltyRatePerDay(uint256 _newRate) external onlyOwner {
    penaltyRatePerDay = _newRate;
  }

  function editDuration(uint256 _newDuration) external onlyOwner {
    duration = _newDuration;
  }

  function _calculateInterest(uint256 _amountBorrowed) private view returns (uint256) {
     return (_amountBorrowed * interestRate) / 100;
  }

  function _calculatePenalty(uint256 _amountToRepay, uint256 _overdueTime) private view returns (uint256) {
    int256 penaltyFeePerDay = (int256(_amountToRepay) * int256(penaltyRatePerDay)) / 100;
    int256 timePassedToDays = int256(_overdueTime) / 1 days;
    
    return uint256(penaltyFeePerDay * timePassedToDays);
  }

  function getBorrower(address _borrower) external returns (Structs.Borrower memory) {
    Structs.Borrower storage borrower = borrowers[_borrower];

     if (block.timestamp > borrower.dueTime) {
      uint256 _overdueTime = block.timestamp - borrower.dueTime;
      
      borrower.penaltyFeeAccrued = _calculatePenalty(borrower.amountToRepay, _overdueTime);
    }

    return borrower;
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

  function getCollateralAssetBalance() external view returns (uint256) {
    return collateralAsset.balanceOf(address(this));
  }

  function _isBorrower(address _borrower) private view returns (bool) {
    return borrowers[_borrower].amountBorrowed > 0;
  }
  
  function isBorrower(address _borrower) external view returns (bool) {
    return _isBorrower(_borrower);
  }

  function getCollateralRate() external view returns (uint256) {
    return collateralRate;
  }
  
  function getDuration() external view returns (uint256) {
    return duration;
  }
  
  function getInterestRate() external view returns (uint256) {
    return interestRate;
  }
  
  function getPenaltyRatePerDay() external view returns (uint256) {
    return penaltyRatePerDay;
  }

  function getVaultAddress() external view returns (address) {
    return address(this);
  }
}