// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("Mock", "MOCK") {
  function mint(uint256 _amount) public {
    _mint(msg.sender, _amount);
  }
}