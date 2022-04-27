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

import "../abstracts/VaultNovaController.sol";
import "../abstracts/VaultChef.sol";

contract VaultFarm is VaultNovaController, VaultChef {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _sToken,
    address _rToken,
    address _vGovernance,
    address _routerAddress,
    address _mChef,
    address _vNova
  ) VaultNovaController(_sToken, _rToken, _rToken, _vGovernance, _vNova) VaultChef(_routerAddress, _mChef){
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function _harvest() internal override {
    (uint harvested, uint treasuryFeeNova, uint buyBackFeeNova) = _getFees();

    _vaultNova.basicDeposit(harvested);

    totalBuyBack = totalBuyBack.add(buyBackFeeNova);
    totalTreasury = totalTreasury.add(treasuryFeeNova);
    totalProfit = totalProfit.add(harvested);

    emit Harvested(harvested, treasuryFeeNova, buyBackFeeNova);

    lastHarvest = block.timestamp;
  }

  function _withdraw(uint _amount) internal override virtual nonReentrant {
    uint amount = Math.min(_amount, _principal[msg.sender]);
    uint shares = Math.min(amount.mul(totalShares).div(balance()), _shares[msg.sender]);
    uint sharesNova = Math.min(amount.mul(1e9).mul(totalSharesNova).div(balanceNova()), _sharesNova[msg.sender]);
    totalShares = totalShares.sub(shares);
    totalSharesNova = totalSharesNova.sub(sharesNova);
    _shares[msg.sender] = _shares[msg.sender].sub(shares);
    _sharesNova[msg.sender] = _sharesNova[msg.sender].sub(sharesNova);
    _principal[msg.sender] = _principal[msg.sender].sub(amount);
    totalStakedBalance = totalStakedBalance.sub(amount);

    resetShares();

    uint withdrawalFee = _vaultGovernance.calculateWithdrawalFee(amount, _depositedAt[msg.sender]);

    if (withdrawalFee > 0) {
      _stakingToken.safeTransfer(_vaultGovernance.treasuryAddress(), withdrawalFee);
      amount = amount.sub(withdrawalFee);
      totalWithdrawalFee = totalWithdrawalFee.add(withdrawalFee);
    }

    _stakingToken.safeTransfer(msg.sender, amount);
    emit Withdrawn(msg.sender, amount, withdrawalFee);
  }

  function _getFees() internal override returns (uint harvested, uint treasuryFeeNova, uint buyBackFeeNova) {
    uint _balanceBefore = _rewardsToken.balanceOf(address(this));
    _masterChef.deposit(_pid, 0);
    _vaultNova.getReward();
    uint _balance = _rewardsToken.balanceOf(address(this)).sub(_balanceBefore);

    treasuryFeeNova = _vaultGovernance.calculateTreasuryFee(_balance);
    buyBackFeeNova = _vaultGovernance.calculateBuyBackFee(_balance);

    _rewardsToken.safeTransfer(_vaultGovernance.buyBackAddress(), buyBackFeeNova);
    _rewardsToken.safeTransfer(_vaultGovernance.treasuryAddress(), treasuryFeeNova);

    harvested = _rewardsToken.balanceOf(address(this)).sub(_balanceBefore);
  }

  function _withdrawNovaTokenWithCorrection(uint amount) internal returns (uint) {
    uint before = _novaToken.balanceOf(address(this));
    _vaultNova.basicWithdraw(amount);
    return _novaToken.balanceOf(address(this)).sub(before);
  }

  function _getReward() internal override nonReentrant {
    uint amount = earned(msg.sender);

    if (amount > 0) {
      _stakingToken.safeTransfer(msg.sender, amount);

      totalShares = totalShares.sub(_shares[msg.sender]);

      if (totalShares == 0) {
        _shares[msg.sender] = principalOf(msg.sender);
      } else {
        uint bal = balance().sub(principalOf(msg.sender));
        _shares[msg.sender] = principalOf(msg.sender).mul(totalShares).div(bal);
      }

      totalShares = totalShares.add(_shares[msg.sender]);
    }

    uint amountNova = earnedNova(msg.sender);

    if (amountNova > 0) {
      amountNova = _withdrawNovaTokenWithCorrection(amountNova);
      _novaToken.safeTransfer(msg.sender, amountNova);

      totalSharesNova = totalSharesNova.sub(_sharesNova[msg.sender]);

      if (totalSharesNova == 0) {
        _sharesNova[msg.sender] = principalOf(msg.sender).mul(1e9);
      } else {
        uint bal = balanceNova().sub(principalOf(msg.sender).mul(1e9));
        _sharesNova[msg.sender] = principalOf(msg.sender).mul(1e9).mul(totalSharesNova).div(bal);
      }

      totalSharesNova = totalSharesNova.add(_sharesNova[msg.sender]);
    }

    emit RewardsPaid(msg.sender, amount, amountNova);
  }

  function _depositTo(uint _amount, address _to) internal override nonReentrant whenNotPaused {
    uint _pool = balance();

    uint _before = _stakingToken.balanceOf(address(this));
    _stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
    uint _after = _stakingToken.balanceOf(address(this));
    _amount = _after.sub(_before);

    uint depositFee = _vaultGovernance.calculateDepositFee(_amount);

    if (depositFee > 0) {
      _stakingToken.safeTransfer(_vaultGovernance.treasuryAddress(), depositFee);
      _amount = _amount.sub(depositFee);
      totalDepositFee = totalDepositFee.add(depositFee);
    }

    uint shares = 0;
    if (totalShares == 0) {
      shares = _amount;
    } else {
      shares = (_amount.mul(totalShares)).div(_pool);
    }

    totalShares = totalShares.add(shares);
    _shares[_to] = _shares[_to].add(shares);
    _principal[_to] = _principal[_to].add(_amount);
    _depositedAt[_to] = block.timestamp;

    uint sharesNova = 0;
    if (totalSharesNova == 0) {
      sharesNova = _amount.mul(1e9);
    } else {
      sharesNova = _amount.mul(1e9).mul(totalSharesNova).div(balanceNova());
    }

    _sharesNova[_to] = _sharesNova[_to].add(sharesNova);
    totalSharesNova = totalSharesNova.add(sharesNova);

    totalStakedBalance = totalStakedBalance.add(_amount);

    emit Deposited(_to, _amount, depositFee);
  }
}
