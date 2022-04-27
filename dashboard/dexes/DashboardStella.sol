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

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IMasterChefStellaswap.sol";

import "./DashboardDex.sol";

contract DashboardStellaswap is DashboardDex, Ownable {
  using SafeMath for uint256;
  uint public blockPerSec = 13;

  constructor(address _chef) DashboardDex(_chef) {
  }

  function setBlockPerSec(uint _blockPerSec) public onlyOwner {
    blockPerSec = _blockPerSec;
  }

  function getDataFromPID(uint pid) public view override returns (DataChef memory data) {
    IMasterChefStellaswap chefStella = IMasterChefStellaswap(address(chef));
    data = DataChef(address(0), 0, 0, 0, 0, 0);
    uint teamPercent = chefStella.teamPercent();
    uint treasuryPercent = chefStella.treasuryPercent();
    uint investorPercent = chefStella.investorPercent();

    uint256 lpPercent = 1000 - teamPercent - treasuryPercent - investorPercent;

    uint rewardsPerBlock = chefStella.stellaPerBlock().mul(lpPercent).div(1000);
    data.rewardPerYear = rewardsPerBlock.mul(60).mul(60).mul(24).mul(365).div(blockPerSec);
    (address token, uint allocPoint,,,,, uint balance) = chefStella.poolInfo(pid);

    data.token = token;
    data.allocPoint = allocPoint;
    data.balance = balance;
    data.totalAllocPoint = chefStella.totalAllocPoint();
    data.poolLength = chefStella.poolLength();
    data.rewardPerYear = data.rewardPerYear.mul(allocPoint).div(data.totalAllocPoint);

    return data;
  }
}
