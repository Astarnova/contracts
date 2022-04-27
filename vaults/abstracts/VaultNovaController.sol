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
import "../abstracts/VaultController.sol";

abstract contract VaultNovaController is VaultController {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  /* ========== STATE VARIABLES ========== */

  IVaultController _vaultNova;

  uint public totalSharesNova;
  uint totalStakedBalance;
  mapping(address => uint) internal _sharesNova;

  /* ========== CONSTRUCTOR ========== */

  constructor(address _sToken, address _rToken, address _nToken, address _vGovernance, address _vNova) VaultController(_sToken, _rToken, _nToken, _vGovernance) {
    _vaultNova = IVaultController(_vNova);
    _novaToken.safeApprove(address(_vaultNova), type(uint256).max);
  }

  /* ========== VIEW FUNCTIONS ========== */

  function balanceNova() public view returns (uint amount) {
    amount = _vaultNova.balanceOf(address(this));
    amount = amount.add(totalStakedBalance.mul(1e9));
  }

  function balanceOfNova(address account) public view returns (uint) {
    if (totalSharesNova == 0) return 0;
    return balanceNova().mul(sharesOfNova(account)).div(totalSharesNova);
  }

  function sharesOfNova(address account) public view returns (uint) {
    return _sharesNova[account];
  }

  function earnedNova(address account) public view returns (uint) {
    uint staked = principalOf(account).mul(1e9);
    uint bNova = balanceOfNova(account);

    if (bNova >= staked) {
      return bNova.sub(staked);
    } else {
      return 0;
    }
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function resetShares() override virtual internal {
    uint shares = _shares[msg.sender];
    uint sharesNova = _sharesNova[msg.sender];

    if (shares > 0 && shares < 1000) {
      totalShares = totalShares.sub(shares);
      delete _shares[msg.sender];
    }

    if (sharesNova > 0 && sharesNova < 1000) {
      totalSharesNova = totalSharesNova.sub(sharesNova);
      delete _sharesNova[msg.sender];
    }
  }
}
