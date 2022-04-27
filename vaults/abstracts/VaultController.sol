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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../interfaces/IVaultGovernance.sol";
import "../interfaces/IVaultController.sol";

abstract contract VaultController is IVaultController, Pausable, ReentrancyGuard, Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  /* ========== STATE VARIABLES ========== */

  IVaultGovernance internal _vaultGovernance;
  IERC20 internal _stakingToken;
  IERC20 internal _rewardsToken;
  IERC20 internal _novaToken;

  uint public lastHarvest;

  uint public totalShares;
  mapping(address => uint) internal _shares;
  mapping(address => uint) internal _principal;
  mapping(address => uint) internal _depositedAt;

  uint public totalBuyBack;
  uint public totalTreasury;
  uint public totalProfit;
  uint public totalDepositFee;
  uint public totalWithdrawalFee;

  /* ========== CONSTRUCTOR ========== */

  constructor(address _sToken, address _rToken, address _nToken, address _vGovernance) {
    _stakingToken = IERC20(_sToken);
    _rewardsToken = IERC20(_rToken);
    _novaToken = IERC20(_nToken);
    _vaultGovernance = IVaultGovernance(_vGovernance);
  }

  /* ========== VIEW FUNCTIONS ========== */

  function totalSupply() external view override returns (uint) {
    return totalShares;
  }

  function balance() public view virtual override returns (uint amount) {
    return _stakingToken.balanceOf(address(this));
  }

  function balanceOf(address account) public view override returns (uint) {
    if (totalShares == 0) return 0;
    return balance().mul(sharesOf(account)).div(totalShares);
  }

  function sharesOf(address account) public view override returns (uint) {
    return _shares[account];
  }

  function principalOf(address account) public view override returns (uint) {
    return _principal[account];
  }

  function earned(address account) public view virtual override returns (uint) {
    if (balanceOf(account) >= principalOf(account)) {
      return balanceOf(account).sub(principalOf(account));
    } else {
      return 0;
    }
  }

  function depositedAt(address account) external view override returns (uint) {
    return _depositedAt[account];
  }

  function stakingToken() external view override returns (address) {
    return address(_stakingToken);
  }

  function rewardsToken() external view override returns (address) {
    return address(_rewardsToken);
  }

  function novaToken() external view override returns (address) {
    return address(_novaToken);
  }

  function vaultGovernance() external view override returns (address) {
    return address(_vaultGovernance);
  }

  function resetShares() virtual internal {
    uint shares = _shares[msg.sender];
    if (shares > 0 && shares < 1000) {
      totalShares = totalShares.sub(shares);
      delete _shares[msg.sender];
    }
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  function basicDeposit(uint _amount) external override {
    _depositTo(_amount, msg.sender);
  }

  function basicWithdraw(uint _amount) external override {
    _withdraw(_amount);
  }

  function deposit(uint _amount) external override {
    _harvest();
    _depositTo(_amount, msg.sender);
  }

  function depositAll() external override {
    _harvest();
    _depositTo(_stakingToken.balanceOf(msg.sender), msg.sender);
  }

  function withdraw(uint _amount) external override {
    _harvest();
    _withdraw(_amount);
  }

  function withdrawAll() external override {
    _harvest();
    _withdraw(balanceOf(msg.sender));
    _getReward();
  }

  function getReward() external virtual override {
    _harvest();
    _getReward();
  }

  function harvest() external virtual override {
    _harvest();
  }

  /* ========== SALVAGE PURPOSE ONLY ========== */

  function emergencyWithdraw(uint _amount) external whenPaused nonReentrant {
    uint amount = Math.min(_amount, _principal[msg.sender]);
    uint shares = Math.min(amount.mul(totalShares).div(balance()), _shares[msg.sender]);
    totalShares = totalShares.sub(shares);
    _shares[msg.sender] = _shares[msg.sender].sub(shares);
    _principal[msg.sender] = _principal[msg.sender].sub(amount);

    resetShares();

    _stakingToken.safeTransfer(msg.sender, amount);

    emit Withdrawn(msg.sender, amount, 0);
  }

  function recoverToken(address _token, uint amount) virtual external onlyOwner nonReentrant {
    require(_token != address(_stakingToken), 'VaultController: cannot recover staking token');
    require(_token != address(_rewardsToken), 'VaultController: cannot recover rewards token');
    require(_token != address(_novaToken), 'VaultController: cannot recover nova token');
    IERC20(_token).safeTransfer(owner(), amount);

    emit Recovered(_token, amount);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function _getFees() internal virtual returns (uint harvested, uint treasuryFeeNova, uint buyBackFeeNova);

  function _getReward() internal virtual;

  function _depositTo(uint _amount, address _to) internal virtual;

  function _withdraw(uint _amount) internal virtual;

  function _harvest() internal virtual;
}
