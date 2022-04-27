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

interface IVaultController {
  function totalSupply() external view returns (uint);
  function balance() external view returns (uint);
  function balanceOf(address account) external view returns (uint);
  function principalOf(address account) external view returns (uint);
  function sharesOf(address account) external view returns (uint);
  function earned(address account) external view returns (uint);
  function depositedAt(address account) external view returns (uint);
  function rewardsToken() external view returns (address);
  function stakingToken() external view returns (address);
  function novaToken() external view returns (address);
  function vaultGovernance() external view returns (address);
  function basicDeposit(uint _amount) external;
  function basicWithdraw(uint _amount) external;
  function deposit(uint _amount) external;
  function depositAll() external;
  function withdraw(uint _amount) external;
  function withdrawAll() external;
  function getReward() external;
  function harvest() external;

  event Deposited(address indexed user, uint amount, uint depositFee);
  event Withdrawn(address indexed user, uint amount, uint withdrawalFee);
  event RewardsPaid(address indexed user, uint rewards, uint rewardsNova);
  event Harvested(uint harvested, uint treasuryFeeInNova, uint buyBackInNova);
  event Recovered(address token, uint amount);
}
