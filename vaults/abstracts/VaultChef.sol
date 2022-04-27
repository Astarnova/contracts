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
import "../resources/TokenChef.sol";

abstract contract VaultChef is Ownable {
  using SafeERC20 for IERC20;

  /* ========== STATE VARIABLES ========== */

  IUniswapV2Router02 internal _router;
  IMasterChef internal _masterChef;
  TokenChef internal _tokenChef;
  uint internal _pid;
  bool addedPid = false;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _routerAddress,
    address _mChef
  ) {
    _tokenChef = new TokenChef();

    _router = IUniswapV2Router02(_routerAddress);
    _masterChef = IMasterChef(_mChef);

    IERC20(_tokenChef).safeApprove(address(_masterChef), type(uint256).max);
  }

  /* ========== VIEW FUNCTIONS ========== */

  function chef() external view returns (address) {
    return address(_masterChef);
  }

  function router() external view returns (address) {
    return address(_router);
  }

  function pid() external view returns (uint) {
    return _pid;
  }

  function tokenChef() external view returns (address) {
    return address(_tokenChef);
  }

  function setPid(uint _chefPid) public virtual onlyOwner {
    require(!addedPid, 'VaultChef: PID can only be added once');
    _pid = _chefPid;
    _masterChef.deposit(_pid, 1e18);
  }
}
