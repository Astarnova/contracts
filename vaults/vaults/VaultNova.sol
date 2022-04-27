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

import "../abstracts/VaultController.sol";
import "../../farm/interfaces/IMasterChef.sol";
import "../../uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../abstracts/VaultChef.sol";

contract VaultNova is VaultController, VaultChef {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _nToken,
    address _vGovernance,
    address _routerAddress,
    address _mChef
  ) VaultController(_nToken, _nToken, _nToken, _vGovernance) VaultChef(_routerAddress, _mChef) {
  }

  function earnedNova(address account) public view returns (uint) {
    return earned(account);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function _getFees() internal override returns (uint harvested, uint treasuryFeeNova, uint buyBackFeeNova) {
    uint _balanceBefore = _rewardsToken.balanceOf(address(this));
    _masterChef.deposit(_pid, 0);
    uint _balance = _rewardsToken.balanceOf(address(this)).sub(_balanceBefore);

    treasuryFeeNova = _vaultGovernance.calculateTreasuryFee(_balance);
    buyBackFeeNova = _vaultGovernance.calculateBuyBackFee(_balance);

    _rewardsToken.safeTransfer(_vaultGovernance.buyBackAddress(), buyBackFeeNova);
    _rewardsToken.safeTransfer(_vaultGovernance.treasuryAddress(), treasuryFeeNova);

    harvested = _rewardsToken.balanceOf(address(this)).sub(_balanceBefore);
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

      emit RewardsPaid(msg.sender, amount, 0);
    }
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

    emit Deposited(_to, _amount, depositFee);
  }

  function _withdraw(uint _amount) internal override nonReentrant {
    uint amount = Math.min(_amount, _principal[msg.sender]);
    uint shares = Math.min(amount.mul(totalShares).div(balance()), _shares[msg.sender]);
    totalShares = totalShares.sub(shares);
    _shares[msg.sender] = _shares[msg.sender].sub(shares);
    _principal[msg.sender] = _principal[msg.sender].sub(amount);

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

  function _harvest() internal override {
    (uint harvested, uint treasuryFeeNova, uint buyBackFeeNova) = _getFees();

    totalBuyBack = totalBuyBack.add(buyBackFeeNova);
    totalTreasury = totalTreasury.add(treasuryFeeNova);
    totalProfit = totalProfit.add(harvested);

    emit Harvested(harvested, treasuryFeeNova, buyBackFeeNova);

    lastHarvest = block.timestamp;
  }
}
