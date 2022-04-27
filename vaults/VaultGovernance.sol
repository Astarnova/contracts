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
* SOFTWARE.
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IVaultGovernance.sol";

contract VaultGovernance is IVaultGovernance, Ownable {
  using SafeMath for uint256;

  uint public constant PERCENTAGE_FEE_MAX = 10000;
  uint public constant WITHDRAWAL_FEE_MAX = 500;
  uint public constant WITHDRAWAL_FEE_FREE_PERIOD_MAX = 30 days;
  uint public constant DEPOSIT_FEE_MAX = 500;
  uint public constant TREASURE_FEE_MAX = 700;
  uint public constant BUY_BACK_FEE_MAX = 1000;

  uint public _withdrawalFee;
  uint public _withdrawalFeeFreePeriod;
  uint public _depositFee;
  uint public _treasuryFee;
  uint public _buyBackFee;

  address public _buyBackAddress;
  address public _treasuryAddress;

  /* ========== OWNER FUNCTIONS ========== */

  function setBuyBackAddress(address _address) external override onlyOwner {
    require(_address != address(0), "VaultGovernance: wrong buyBackAddress");
    _buyBackAddress = _address;
  }

  function setTreasuryAddress(address _address) external override onlyOwner {
    require(_address != address(0), "VaultGovernance: wrong treasuryAddress");
    _treasuryAddress = _address;
  }

  function setWithdrawalFeeFreePeriod(uint _period) external override onlyOwner {
    require(_period <= WITHDRAWAL_FEE_FREE_PERIOD_MAX, "VaultGovernance: wrong withdrawalFeeFreePeriod");
    _withdrawalFeeFreePeriod = _period;
  }

  function setWithdrawalFee(uint _fee) external override onlyOwner {
    require(_fee <= WITHDRAWAL_FEE_MAX, "VaultGovernance: wrong withdrawalFee");
    _withdrawalFee = _fee;
  }

  function setDepositFee(uint _fee) external override onlyOwner {
    require(_fee <= DEPOSIT_FEE_MAX, "VaultGovernance: wrong depositFee");
    _depositFee = _fee;
  }

  function setTreasuryFee(uint _fee) external override onlyOwner {
    require(_fee <= TREASURE_FEE_MAX, "VaultGovernance: wrong treasuryFee");
    _treasuryFee = _fee;
  }

  function setBuyBackFee(uint _fee) external override onlyOwner {
    require(_fee <= BUY_BACK_FEE_MAX, "VaultGovernance: wrong buyBackFee");
    _buyBackFee = _fee;
  }

  /* ========== VIEW FUNCTIONS ========== */

  function calculateWithdrawalFee(uint amount, uint depositedAt) public view override returns (uint) {
    if (depositedAt.add(_withdrawalFeeFreePeriod) > block.timestamp) {
      return calculateFee(amount, _withdrawalFee);
    }
    return 0;
  }

  function calculateDepositFee(uint amount) public view override returns (uint) {
    return calculateFee(amount, _depositFee);
  }

  function calculateTreasuryFee(uint amount) public view override returns (uint) {
    return calculateFee(amount, _treasuryFee);
  }

  function calculateBuyBackFee(uint amount) public view override returns (uint) {
    return calculateFee(amount, _buyBackFee);
  }

  function calculateNovaFee(uint amount, uint option) public view override returns (uint) {
    return calculateProfitNovaFee(amount, option);
  }

  function withdrawalFee() public view override returns (uint) {
    return _withdrawalFee;
  }

  function withdrawalFeeFreePeriod() public view override returns (uint) {
    return _withdrawalFeeFreePeriod;
  }

  function depositFee() public view override returns (uint) {
    return _depositFee;
  }

  function treasuryFee() public view override returns (uint) {
    return _treasuryFee;
  }

  function buyBackFee() public view override returns (uint) {
    return _buyBackFee;
  }

  function buyBackAddress() public view override returns (address) {
    return _buyBackAddress;
  }

  function treasuryAddress() public view override returns (address) {
    return _treasuryAddress;
  }

  /* ========== PRIVATE FUNCTIONS ========== */

  function calculateFee(uint amount, uint percentage) private pure returns (uint) {
    return amount.mul(percentage).div(PERCENTAGE_FEE_MAX);
  }

  function calculateProfitNovaFee(uint amount, uint option) private view returns (uint) {
    uint totalFee = _treasuryFee.add(_buyBackFee);

    if (option == 1) { // Treasury fee
     return _treasuryFee.mul(amount).div(totalFee);
    } else if (option == 2) { // Buy Back fee
      return _buyBackFee.mul(amount).div(totalFee);
    }

    return 0;
  }
}
