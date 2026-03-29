// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Structs, Errors } from "../types/Types.sol";
import { LoanVault } from "./LoanVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Project is Ownable(msg.sender) {
  uint256 public constant PROTOCOL_FEE_DECIMAL_POINT = 2; // 2 decimal places
  uint256 private protocolFee = 50; // 0.50% of Lenders'withdrawals/liquidation amounts || Setting ordinary 5 === 0.05%

  uint256 private minimumInitialDeposit = 100;

  mapping(address lender => Structs.Lender lenderDetails) private lendersDetail;
  LoanVault[] private allVaults;

  modifier onlyLender() {
    _onlyLender();
    _;
  }

  function registerAsLender() public {
    if (_isLender(msg.sender)) revert Errors.Project__IsAlreadyALender();

    Structs.Lender storage lender = lendersDetail[msg.sender];

    lender.lenderAddress = msg.sender;
    lender.joinedAt = block.timestamp;
  }

  function createLoanVault(address _lendingAsset, uint256 _amount, address _collateralAsset, uint256 _collateralRate, uint256 _interestRate, uint256 _penaltyRatePerDay,  uint256 _duration) external onlyLender {
    if (_amount < minimumInitialDeposit) revert Errors.Project__InvalidInitialDeposit();
    require(IERC20(_lendingAsset).transferFrom(msg.sender, address(this), _amount));

    LoanVault loanVault = new LoanVault(address(this), msg.sender, IERC20(_lendingAsset), IERC20(_collateralAsset), _collateralRate, _interestRate, _penaltyRatePerDay, _duration);
    require(IERC20(_lendingAsset).transfer(address(loanVault), _amount));

    Structs.Lender storage lender = lendersDetail[msg.sender];

    lender.loanVaults[_lendingAsset] = loanVault;

    allVaults.push(loanVault);
  }

  function _isLender(address lender) private view returns (bool) {
    return lendersDetail[lender].lenderAddress == lender;
  }

  function isLender(address lender) external view returns (bool) {
    return _isLender(lender);
  }

  function _onlyLender() private view {
    if (!_isLender(msg.sender)) revert Errors.Project__NotALender();
  }

  function updateProtocolFee(uint256 _fee) external onlyOwner {
    protocolFee = _fee;
  }

  function withdraw(address tokenAddress, uint256 amount) external onlyOwner {
    IERC20(tokenAddress).transfer(owner(), amount);
  }

  function setProtocolFee(uint256 _fee) external onlyOwner {
    protocolFee = _fee;
  }

  function getLenderDetails(address _lender) external view returns (address, uint256) {
    Structs.Lender storage lender = lendersDetail[_lender];

    return (lender.lenderAddress, lender.joinedAt);
  }

  function getLoanVault(address _lender, address debtAsset) external view returns (LoanVault) {
    Structs.Lender storage lenderDetails = lendersDetail[_lender];
    return lenderDetails.loanVaults[debtAsset];
  }

  function getAllVaults() external view returns (LoanVault[] memory) {
    return allVaults;
  }

  function getVaultsCount() external view returns (uint256) {
    return allVaults.length;
  }

  function getProtocolFee() external view returns (uint256) {
    return protocolFee;
  }
}