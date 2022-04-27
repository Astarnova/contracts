// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
*
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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./DashboardDex.sol";
import "../../farm/interfaces/IMasterChef.sol";

abstract contract DashboardDex {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  IMasterChef chef;

  struct DataChef {
    address token;
    uint allocPoint;
    uint balance;
    uint rewardPerYear;
    uint totalAllocPoint;
    uint poolLength;
  }

  constructor(address _chef) {
    chef = IMasterChef(_chef);
  }

  function getDataFromPID(uint pid) public view virtual returns (DataChef memory data) {
    data = DataChef(address(0), 0, 0, 0, 0, 0);

    (,,,uint256[] memory rewardsPerSec) = chef.poolRewardsPerSec(pid);
    data.rewardPerYear = rewardsPerSec[0].mul(60).mul(60).mul(24).mul(365);
    (address token, uint allocPoint,,,,, uint balance) = chef.poolInfo(pid);

    data.token = token;
    data.allocPoint = allocPoint;
    data.balance = balance;
    data.totalAllocPoint = chef.totalAllocPoint();
    data.poolLength = chef.poolLength();

    return data;
  }
}
