// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Structs, Errors } from "../types/Types.sol";

contract Project {
  mapping(address lender => Structs.Lender lenderDetails) private lendersDetail;

  function registerAsLender() public {
    if (_isLender(msg.sender)) revert Errors.Project__IsAlreadyALender();

    Structs.Lender memory lender;
    lender.lenderAddress = msg.sender;
    lender.joinedAt = block.timestamp;

    lendersDetail[msg.sender] = lender;
  }

  function _isLender(address lender) private view returns (bool) {
    return lendersDetail[lender].lenderAddress == lender;
  }

  function isLender(address lender) external view returns (bool) {
    return _isLender(lender);
  }
}