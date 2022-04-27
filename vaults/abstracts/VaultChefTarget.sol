// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
* MIT License
* ===========
*
* Copyright (c) 2021 Astarnova
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../farm/interfaces/IMasterChef.sol";
import "../../uniswapv2/interfaces/IUniswapV2Router02.sol";

abstract contract VaultChefTarget is Ownable {
  using SafeERC20 for IERC20;

  /* ========== STATE VARIABLES ========== */

  IUniswapV2Router02 internal _routerTarget;
  IMasterChef internal _masterChefTarget;
  uint internal _pidTarget;

  IERC20 internal _base;

  address[] public rewardToBaseRoute;

  address[] public baseToNovaRoute;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address[] memory _rewardToBaseRoute,
    address[] memory _baseToNovaRoute
  ) {
    rewardToBaseRoute = _rewardToBaseRoute;
    baseToNovaRoute = _baseToNovaRoute;
    _base = IERC20(baseToNovaRoute[0]);

    require(rewardToBaseRoute[rewardToBaseRoute.length - 1] == baseToNovaRoute[0], "rewardToBaseRoute[last] != baseToNovaRoute[0]");
  }

  function setTarget(address _routerAddressTarget, address _mChefTarget, uint _chefPidTarget) public virtual onlyOwner {
    require(address(_routerTarget) == address(0), 'VaultChefTarget: Target can only be added once');
    _routerTarget = IUniswapV2Router02(_routerAddressTarget);
    _masterChefTarget = IMasterChef(_mChefTarget);
    _pidTarget = _chefPidTarget;
  }

  /* ========== VIEW FUNCTIONS ========== */

  function base() external view returns (address) {
    return address(_base);
  }

  function chefTarget() external view returns (address) {
    return address(_masterChefTarget);
  }

  function routerTarget() external view returns (address) {
    return address(_routerTarget);
  }

  function pidTarget() external view returns (uint) {
    return _pidTarget;
  }

}
