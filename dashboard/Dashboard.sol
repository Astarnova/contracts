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

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../vaults/interfaces/IVaultChef.sol";
import "../vaults/interfaces/IVaultChefTarget.sol";
import "../vaults/interfaces/IVaultController.sol";
import "../farm/interfaces/IMasterChef.sol";
import "../vaults/interfaces/IVaultChefWithNova.sol";
import "../vaults/interfaces/IVaultGovernance.sol";

import "./interfaces/IDashboardDex.sol";
import "./interfaces/IPriceCalculator.sol";
import "./library/SafeDecimal.sol";

contract Dashboard is Ownable {
  using SafeMath for uint;
  using SafeDecimal for uint;

  enum VaultTypes {
    FARM,
    OPTIMIZER
  }

  /* ========== STATE VARIABLES ========== */

  IPriceCalculator public priceCalculator;
  IERC20 public novaToken;
  IDashboardDex public dashboardAstarnova;

  mapping(address => address) public dashboardDex;
  mapping(address => VaultTypes) public vaultType;

  /* ========== Restricted Operation ========== */

  function setDashboarDex(address vault, address dashboard) public onlyOwner {
    dashboardDex[vault] = dashboard;
  }

  function setVaultType(address pool, VaultTypes _vaultType) public onlyOwner {
    vaultType[pool] = _vaultType;
  }

  /* ========== View Functions ========== */

  constructor(address _priceCalculator, address _nova, address _dAstarnova) {
    priceCalculator = IPriceCalculator(_priceCalculator);
    novaToken = IERC20(_nova);
    dashboardAstarnova = IDashboardDex(_dAstarnova);
  }

  /* ========== Profit Calculation ========== */

  function marketCap() public view returns (uint) {
    uint totalSupply = novaToken.totalSupply();
    return priceCalculator.valueOfAsset(address(novaToken), totalSupply);
  }

  function calculateRewards(address _vault, address account) public view returns (uint) {
    IVaultController vault = IVaultController(_vault);
    uint earned = vault.earned(account);
    return priceCalculator.valueOfAsset(vault.stakingToken(), earned);
  }

  function calculateNova(address _vault, address account) public view returns (uint) {
    IVaultChefWithNova vault = IVaultChefWithNova(_vault);
    uint earned = vault.earnedNova(account);
    return priceCalculator.valueOfAsset(vault.novaToken(), earned);
  }

  function profitOfVault(address _vault, address _account) public view returns (uint rewards, uint nova) {
    rewards = calculateRewards(_vault, _account);
    nova = calculateNova(_vault, _account);
  }

  function novaPerDay(address _vault) public view returns (uint) {
    IDashboardDex.DataChef memory data;
    if (vaultType[_vault] == VaultTypes.OPTIMIZER) {
      data = dashboardAstarnova.getDataFromPID(IVaultChefTarget(_vault).pidTarget());
    } else {
      data = dashboardAstarnova.getDataFromPID(IVaultChef(_vault).pid());
    }

    return data.rewardPerYear.div(365);
  }

  /* ========== TVL Calculation ========== */

  function tvlOfPool(address _vault) public view returns (uint) {
    IVaultController vault = IVaultController(_vault);
    return priceCalculator.valueOfAsset(vault.stakingToken(), vault.balance());
  }

  /* ========== Portfolio Calculation ========== */

  function stakingTokenValueInUSD(address vault, address account) internal view returns (uint) {
    address stakingToken = IVaultController(vault).stakingToken();

    if (stakingToken == address(0)) return 0;
    return priceCalculator.valueOfAsset(stakingToken, IVaultController(vault).principalOf(account));
  }

  function novaAPR(address _vault) private view returns (uint) {
    if (vaultType[_vault] == VaultTypes.OPTIMIZER) {
      IVaultChefTarget vault = IVaultChefTarget(_vault);
      IDashboardDex.DataChef memory data = dashboardAstarnova.getDataFromPID(vault.pidTarget());

      if (vault.pid() >= data.poolLength) return 0;
      uint tvlToken = priceCalculator.valueOfAsset(vault.stakingToken(), vault.balance());

      if (tvlToken == 0) return 0;
      uint valueReward = priceCalculator.valueOfAsset(vault.novaToken(), 10 ** IERC20Metadata(vault.novaToken()).decimals());

      return valueReward.mul(data.rewardPerYear).div(tvlToken);
    }

    return rewardChefCompound(IVaultChef(_vault), dashboardAstarnova);
  }

  function rewardChefCompound(IVaultChef vault, IDashboardDex dashboard) private view returns (uint) {
    IDashboardDex.DataChef memory data = dashboard.getDataFromPID(vault.pid());

    if (vault.pid() >= data.poolLength) return 0;
    uint tvlToken = priceCalculator.valueOfAsset(vault.stakingToken(), vault.balance());

    if (tvlToken == 0) return 0;
    uint valueReward = priceCalculator.valueOfAsset(vault.rewardsToken(), 10 ** IERC20Metadata(vault.rewardsToken()).decimals());

    return valueReward.mul(data.rewardPerYear).div(tvlToken);
  }

  function aprOfVault(address _vault) public view returns (uint aprReward, uint aprNova) {
    aprNova = novaAPR(_vault);
    aprReward = aprRewardAction(_vault);
  }

  function apyOfVault(address _vault) public view returns (uint apyReward, uint apyNova) {
    apyNova = novaAPR(_vault);

    if (apyNova <= 15e18) {
      apyNova = apyNova.div(365).add(1e18).power(365).sub(1e18);
    } else {
      apyNova = 0;
    }
    apyReward = aprRewardAction(_vault);

    if (apyReward <= 15e18) {
      apyReward = apyReward.div(365).add(1e18).power(365).sub(1e18);
    } else {
      apyReward = 0;
    }
  }

  function aprRewardAction(address _vault) private view returns (uint) {
    uint aprReward = 0;
    IVaultChefWithNova vault = IVaultChefWithNova(_vault);
    aprReward = rewardChefCompound(vault, IDashboardDex(dashboardDex[address(vault)]));
    return aprReward;
  }

  function portfolioOfPoolInUSD(address _vault, address account) internal view returns (uint) {
    uint tokenInUSD = stakingTokenValueInUSD(_vault, account);
    uint rewardsUSD = calculateRewards(_vault, account);
    address[] memory vaults = new address[](1);
    vaults[0] = _vault;
    (uint novaEarned) = novaEarnedOf(account, vaults);
    uint rewardsNovaUSD = priceCalculator.valueOfAsset(address(novaToken), novaEarned);

    return tokenInUSD.add(rewardsUSD).add(rewardsNovaUSD);
  }

  function portfolioOf(address account, address[] memory vaults) public view returns (uint deposits) {
    deposits = 0;
    for (uint i = 0; i < vaults.length; i++) {
      deposits = deposits.add(portfolioOfPoolInUSD(vaults[i], account));
    }
  }

  function novaEarnedOf(address account, address[] memory vaults) public view returns (uint nova) {
    nova = 0;
    for (uint i = 0; i < vaults.length; i++) {
      IVaultChefWithNova vault = IVaultChefWithNova(vaults[i]);
      nova = nova.add(vault.earnedNova(account));
    }
  }

  function aprOf(address account, address[] memory vaults) public view returns (uint apr) {
    (uint totalAssets) = portfolioOf(account, vaults);
    apr = 0;
    uint rewards = 0;

    for (uint i = 0; i < vaults.length; i++) {
      uint portfolio = portfolioOfPoolInUSD(vaults[i], account);
      if (portfolio > 0) {
        (uint aprVault, uint aprNova) = aprOfVault(vaults[i]);
        uint aprTotal = aprNova.add(aprVault);
        rewards = rewards.add(portfolio.mul(aprTotal));
      }
    }

    if (rewards != 0) {
      apr = rewards.div(totalAssets);
    }
  }
}
