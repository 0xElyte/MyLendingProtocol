// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Structs } from "./Structs.sol";

contract Project {
  function registerLender() public {
    Structs.Lender memory lender = Structs.Lender({
      lenderAddress: msg.sender,
    });
  }
}