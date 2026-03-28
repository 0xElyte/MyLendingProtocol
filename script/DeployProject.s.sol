// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import { Script } from "forge-std/Script.sol";
import { Project } from "../src/core/Project.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployProject is Script {
  function run() external returns (Project) {
    vm.startBroadcast();

    Project project = new Project();

    vm.stopBroadcast();

    return project;
  }
}