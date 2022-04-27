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
import "../abstracts/VaultChefTarget.sol";
import "../../uniswapv2/interfaces/IUniswapV2Pair.sol";

contract VaultOptimizer is VaultNovaController, VaultChef, VaultChefTarget {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  /* ========== STATE VARIABLES ========== */

  address public token0;
  address public token1;

  address[] public rewardToToken0Route;
  address[] public rewardToToken1Route;

  address[] public token0ToReward;
  address[] public token1ToReward;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _sToken,
    address _vGovernance,
    address _routerAddress,
    address _mChef,
    address _vNova,
    address[] memory _rewardToBaseRoute,
    address[] memory _baseToNovaRoute,
    address[] memory _rewardToToken0Route,
    address[] memory _rewardToToken1Route
  ) VaultNovaController(_sToken, _rewardToBaseRoute[0], _baseToNovaRoute[_baseToNovaRoute.length - 1], _vGovernance, _vNova)
    VaultChef(_routerAddress, _mChef)
    VaultChefTarget(_rewardToBaseRoute, _baseToNovaRoute)
  {
    rewardToToken0Route = _rewardToToken0Route;
    rewardToToken1Route = _rewardToToken1Route;

    for (uint i = 0; i < rewardToToken0Route.length; i++) {
      token0ToReward.push(rewardToToken0Route[rewardToToken0Route.length - i - 1]);
    }

    for (uint i = 0; i < rewardToToken1Route.length; i++) {
      token1ToReward.push(rewardToToken1Route[rewardToToken1Route.length - i - 1]);
    }

    token0 = IUniswapV2Pair(_sToken).token0();
    token1 = IUniswapV2Pair(_sToken).token1();

    _base.safeApprove(address(_router), type(uint256).max);

    require(rewardToToken0Route[rewardToToken0Route.length - 1] == token0, "rewardToToken0Route[last] != token0");
    require(rewardToToken1Route[rewardToToken1Route.length - 1] == token1, "rewardToToken1Route[last] != token1");
    require(rewardToBaseRoute[0] == _rewardToToken0Route[0], "rewardToBaseRoute[0] != _rewardToToken0Route[0]");
    require(rewardToBaseRoute[0] == _rewardToToken1Route[0], "rewardToBaseRoute[0] != _rewardToToken1Route[0]");
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function _harvest() internal override {
    _masterChefTarget.deposit(_pidTarget, 0);
    _masterChef.deposit(_pid, 0);
    _vaultNova.getReward();

    uint before = _stakingToken.balanceOf(address(this));
    (, uint treasuryFeeNova, uint buyBackFeeNova) = _addLiquidity();
    uint harvested = _stakingToken.balanceOf(address(this)).sub(before);

    _masterChefTarget.deposit(_pidTarget, harvested);

    totalBuyBack = totalBuyBack.add(buyBackFeeNova);
    totalTreasury = totalTreasury.add(treasuryFeeNova);
    totalProfit = totalProfit.add(harvested);

    emit Harvested(harvested, treasuryFeeNova, buyBackFeeNova);

    lastHarvest = block.timestamp;
  }

  function _getFees() internal override returns (uint harvested, uint treasuryFeeNova, uint buyBackFeeNova) {
    address treasuryAddress = _vaultGovernance.treasuryAddress();
    address buyBackAddress = _vaultGovernance.buyBackAddress();

    uint rewardBalance = _rewardsToken.balanceOf(address(this));

    treasuryFeeNova = 0;
    buyBackFeeNova = 0;
    harvested = 0;

    try _routerTarget.swapExactTokensForTokens(rewardBalance, 1, rewardToBaseRoute, address(this), block.timestamp) {
      uint baseBalance = _base.balanceOf(address(this));

      try _router.swapExactTokensForTokens(baseBalance, 10, baseToNovaRoute, address(this), block.timestamp) {
        uint novaBalance = _novaToken.balanceOf(address(this));

        treasuryFeeNova = _vaultGovernance.calculateNovaFee(novaBalance, 1);
        buyBackFeeNova = _vaultGovernance.calculateNovaFee(novaBalance, 2);

        _novaToken.safeTransfer(treasuryAddress, treasuryFeeNova);
        _novaToken.safeTransfer(buyBackAddress, buyBackFeeNova);
      } catch {}
    } catch {}
  }

  function _addLiquidity() internal returns (uint liquidity, uint treasuryFee, uint buyBackFee) {
    uint256 balance = _rewardsToken.balanceOf(address(this));
    liquidity = 0;
    treasuryFee = 0;
    buyBackFee = 0;

    if (balance > 0) {
      uint treasuryAmount = _vaultGovernance.calculateTreasuryFee(balance);
      uint buyBackAmount = _vaultGovernance.calculateBuyBackFee(balance);

      uint256 half = balance.sub(treasuryAmount).sub(buyBackAmount).div(2);

      bool existsBuyAmountToken0 = false;
      bool existsBuyAmountToken1 = false;

      if (token0 != address(_rewardsToken)) {
        try _routerTarget.getAmountsOut(half, rewardToToken0Route) returns (uint[] memory amounts) {
          if (amounts[rewardToToken0Route.length - 1] > 0) {
            existsBuyAmountToken0 = true;
          }
        } catch {}
      } else {
        existsBuyAmountToken0 = true;
      }

      if (token1 != address(_rewardsToken)) {
        try _routerTarget.getAmountsOut(half, rewardToToken1Route) returns (uint[] memory amounts) {
          if (amounts[rewardToToken1Route.length - 1] > 0) {
            existsBuyAmountToken1 = true;
          }
        } catch {}
      } else {
        existsBuyAmountToken1 = true;
      }

      if (existsBuyAmountToken0 && existsBuyAmountToken1) {
        if (token0 != address(_rewardsToken)) {
          try _routerTarget.swapExactTokensForTokens(half, 0, rewardToToken0Route, address(this), block.timestamp) {} catch {}
        }

        if (token1 != address(_rewardsToken)) {
          try _routerTarget.swapExactTokensForTokens(half, 0, rewardToToken1Route, address(this), block.timestamp) {} catch {}
        }

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        try _routerTarget.addLiquidity(token0, token1, token0Balance, token1Balance, 1, 1, address(this), block.timestamp) returns (uint, uint, uint x) {
          liquidity = x;
          (,treasuryFee, buyBackFee) = _getFees();
        } catch {}

        token0Balance = IERC20(token0).balanceOf(address(this));
        token1Balance = IERC20(token1).balanceOf(address(this));

        if (token0Balance > 0) {
          try _routerTarget.swapExactTokensForTokens(token0Balance, 0, token0ToReward, address(this), block.timestamp) {} catch {}
        }

        if (token1Balance > 0) {
          try _routerTarget.swapExactTokensForTokens(token1Balance, 0, token1ToReward, address(this), block.timestamp) {} catch {}
        }
      }
    }
  }

  function _withdraw(uint _amount) internal override nonReentrant {
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
