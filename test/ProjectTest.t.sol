// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Test, console2 } from "forge-std/Test.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";
import { Project } from "../src/core/Project.sol";
import { LoanVault } from "../src/core/LoanVault.sol";
import { DeployProject } from "../script/DeployProject.s.sol";
import { Structs, Errors } from "../src/types/Types.sol";

contract ProjectTest is Test {
  address lender = makeAddr("lender1");
  address borrower = makeAddr("borrower1");

  Project projectContract;

  MockERC20 lendingAsset;
  MockERC20 collateralAsset;
  
  uint256 collateralRate = 10;
  uint256 duration = 1 hours;
  uint256 _interestRate = 5;
  uint256 _penaltyRatePerDay = 2;

  function setUp() public {
    DeployProject deployScript = new DeployProject();
    projectContract = deployScript.run();

    lendingAsset = new MockERC20();
    collateralAsset = new MockERC20();
  }

  modifier createVault() {
    // Successfully Creates Vault for a regstered lender
    vm.startBroadcast(lender);

    projectContract.registerAsLender();
    assertTrue(projectContract.isLender(lender));

    projectContract.createLoanVault(address(lendingAsset), address(collateralAsset), collateralRate, _interestRate, _penaltyRatePerDay, duration);
    
    (address lenderAddress, ) = projectContract.getLenderDetails(lender);
    assertEq(lenderAddress, lender);

    LoanVault vault = projectContract.getLoanVault(lender, address(lendingAsset));

    assertTrue(vault.getLendingAsset() == address(lendingAsset));
    assertTrue(vault.getCollateralAsset() == address(collateralAsset));
    assertTrue(vault.getCollateralRate() == collateralRate);
    assertTrue(vault.getDuration() == duration);
    assertEq(vault.owner(), lender);

    vm.stopBroadcast();

    _;
  }

  function test__RegisterAsLender() public {
    vm.prank(lender);
    projectContract.registerAsLender();

    assertTrue(projectContract.isLender(lender));
  }

  function test__CreateLoanVault() public createVault {
    // Cannot create Vault when not registered as a Lender
    vm.prank(borrower);
  vm.expectRevert(Errors.Project__NotALender.selector);
    projectContract.createLoanVault(address(lendingAsset), address(collateralAsset), collateralRate, _interestRate, _penaltyRatePerDay, duration);
  }

  function test__BorrowAndRepaymentLifecycle() public createVault {
    LoanVault _loanVault = projectContract.getLoanVault(lender, address(lendingAsset));
    uint256 _liquidityAmount = 1000;
    uint256 _amount = 100;
    uint256 _amountCollateral = _loanVault.getTotalCollateralForLoan(_amount);
    
    // Vault Exists but has insufficient debtAsset amount
    vm.prank(borrower);
    vm.expectRevert(Errors.LoanVault__InsufficientLoanVaultBalance.selector);
    _loanVault.borrow(_amount);

  // Vault has asset but borrowe has insufficient collateralAsset amount
    vm.startPrank(lender);

    lendingAsset.mint(_liquidityAmount);
    lendingAsset.approve(address(_loanVault), _liquidityAmount);
    _loanVault.addLiquidity(_liquidityAmount);

    vm.stopPrank();

    vm.startPrank(borrower);

    vm.expectRevert(Errors.LoanVault__InsufficientBorrowerCollateralBalance.selector);
    _loanVault.borrow(_amount);
    
    collateralAsset.mint(_amountCollateral);
    collateralAsset.approve(address(_loanVault), _amountCollateral);

    vm.expectRevert(Errors.LoanVault__InsufficientBorrowerCollateralBalance.selector);
    _loanVault.borrow(_amountCollateral); // more than balance + collateral

    // Successfully Borrows
    _loanVault.borrow(_amount);

    vm.stopPrank();

    assertEq(_loanVault.getCollateralAssetBalance(), _amountCollateral);
    assertEq(_loanVault.getLendingAssetBalance(), _liquidityAmount - _amount);
    assertEq(lendingAsset.balanceOf(borrower), _amount);

    uint256 _borrowedAt = _loanVault.getBorrower(borrower).borrowedAt;
    uint256 _dueTime = _loanVault.getBorrower(borrower).dueTime;

    assertEq(_dueTime, _borrowedAt + _loanVault.getDuration());

    // Cannot borrow when still owing
    vm.startPrank(borrower);
    
    vm.expectRevert(abi.encodeWithSelector(Errors.LoanVault__HasOutstandingLoan.selector, _amount));
    _loanVault.borrow(_amount);

    console2.log("Before Repayment...");
    Structs.Borrower memory borrowerDetails = _loanVault.getBorrower(borrower);

    console2.logAddress( borrowerDetails.borrowerAddress);
    console2.logAddress(borrowerDetails.lenderAddress);
    console2.logAddress(address(borrowerDetails.loanAsset));
    console2.logAddress(address(borrowerDetails.debtAsset));
    console2.logUint(borrowerDetails.amountBorrowed);
    console2.logUint(borrowerDetails.amountToRepay);
    console2.logUint(borrowerDetails.penaltyFeeAccrued);
    console2.logUint(borrowerDetails.amountColateralDropped);
    console2.logUint(borrowerDetails.borrowedAt);
    console2.logUint(borrowerDetails.dueTime);
    console2.log("===========================================================");
    
    // Test On-Time Repayment
    lendingAsset.mint(_amount);
    uint256 repaymentAmount = borrowerDetails.amountToRepay;
    lendingAsset.approve(address(_loanVault), repaymentAmount);
    _loanVault.repay(repaymentAmount);

    console2.log("After Repayment...");
    borrowerDetails = _loanVault.getBorrower(borrower);

    console2.logAddress( borrowerDetails.borrowerAddress);
    console2.logAddress(borrowerDetails.lenderAddress);
    console2.logAddress(address(borrowerDetails.loanAsset));
    console2.logAddress(address(borrowerDetails.debtAsset));
    console2.logUint(borrowerDetails.amountBorrowed);
    console2.logUint(borrowerDetails.amountToRepay);
    console2.logUint(borrowerDetails.penaltyFeeAccrued);
    console2.logUint(borrowerDetails.amountColateralDropped);
    console2.logUint(borrowerDetails.borrowedAt);
    console2.logUint(borrowerDetails.dueTime);
    console2.log("===========================================================");

    vm.stopPrank();
  }

  function test__UpdateVaultDetails() public createVault {
    LoanVault loanVault = projectContract.getLoanVault(lender, address(lendingAsset));

  // Unauthorized cannot update
    vm.prank(borrower);
    vm.expectRevert();
    loanVault.editDuration(1);

    // Successfully Edits by Authorized
    uint256 newCollateralRate = 20;
    uint256 newInterestRate = 10;
    uint256 newPenaltyRatePerDay = 5;
    uint256 newDuration = 1 days;
    
    vm.startPrank(lender);

    loanVault.editCollateralRate(newCollateralRate);
    loanVault.editInterestRate(newInterestRate);
    loanVault.editPenaltyRatePerDay(newPenaltyRatePerDay);
    loanVault.editDuration(newDuration);

    vm.stopPrank();

    assertEq(loanVault.getCollateralRate(), newCollateralRate);
    assertEq(loanVault.getInterestRate(), newInterestRate);
    assertEq(loanVault.getPenaltyRatePerDay(), newPenaltyRatePerDay);
    assertEq(loanVault.getDuration(), newDuration);
  }
}

/*
0xDE62c19Ed5877f91A76D9FD44a1B86837b4Dce57
  0x2D4633E7CB8fa70fc8Ab9Ed9dCa6502da3985f3E
  0x2e234DAe75C793f67A35089C9d99245E1C58470b
  0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
  100
  105
  2
  110
  1
  3601

*/