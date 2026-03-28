// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Project } from "../src/core/Project.sol";
import { DeployProject } from "../script/DeployProject.s.sol";
import { Test } from "forge-std/Test.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ProjectTest is Test {
  address lender = makeAddr("lender1");
  address borrower = makeAddr("borrower1");

  Project projectContract;

  function setUp() public {
    DeployProject deployScript = new DeployProject();
    projectContract = deployScript.run();
  }

  function testRegisterAsLender() public {
    vm.prank(lender);
    projectContract.registerAsLender();

    assertTrue(projectContract.isLender(lender));
  }
}