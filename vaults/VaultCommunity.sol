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
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract VaultCommunity is ReentrancyGuard, Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  event RewardsPaid(address indexed user, uint rewards);
  event AddedPointsToUser(address indexed user, uint points);
  event RemovePointsToUser(address indexed user, uint points);
  event MaintainerTransferred(address indexed previousOwner, address indexed newOwner);

  /* ========== STATE VARIABLES ========== */
  IERC20 internal _novaToken;

  uint public quantityUsers;
  uint public totalPoints;
  uint public totalShares;
  address private _maintainer;
  mapping(address => uint) internal _shares;
  mapping(address => uint) internal _principal;

  modifier onlyMaintainerOrOwner() {
    require(owner() == _msgSender() || maintainer() == _msgSender(), "VaultPresale: caller is not the owner or maintainer");
    _;
  }

  /* ========== CONSTRUCTOR ========== */

  constructor(address _nToken) {
    _novaToken = IERC20(_nToken);
  }

  /* ========== VIEW FUNCTIONS ========== */

  function balance() public view returns (uint amount) {
    amount = _novaToken.balanceOf(address(this));
    amount = amount.add(totalPoints.mul(1e9));
  }

  function
  balanceOf(address account) public view returns (uint) {
    if (totalShares == 0) return 0;
    return balance().mul(sharesOf(account)).div(totalShares);
  }

  function sharesOf(address account) public view returns (uint) {
    return _shares[account];
  }

  function principalOf(address account) public view returns (uint) {
    return _principal[account];
  }

  function earned(address account) public view returns (uint) {
    uint staked = principalOf(account).mul(1e9);
    uint bNova = balanceOf(account);

    if (bNova >= staked) {
      return bNova.sub(staked);
    } else {
      return 0;
    }
  }

  function maintainer() public view virtual returns (address) {
    return _maintainer;
  }

  function transferMaintainer(address newMaintainer) public onlyOwner {
    require(newMaintainer != address(0), "VaultPresale: new maintainer is the zero address");
    _setMaintainer(newMaintainer);
  }

  function _setMaintainer(address newMaintainer) private {
    address oldMaintainer = _maintainer;
    _maintainer = newMaintainer;
    emit MaintainerTransferred(oldMaintainer, newMaintainer);
  }

  function addPointToUser(address _user, uint _amount) external {
    _addPointsToUser(_user, _amount);
  }

  function addPointToUserMultiple(address[] memory _user, uint[] memory _amount) external {
    for (uint i = 0; i < _user.length; i++) {
      _addPointsToUser(_user[i], _amount[i]);
    }
  }

  function removeAllPointsToUser(address user) external {
    _removePointsToUser(user, balanceOf(user));
  }

  function removePointsToUser(address user, uint amount) external {
    _removePointsToUser(user, amount);
  }

  function novaToken() external view returns (address) {
    return address(_novaToken);
  }

  function getReward() external {
    _getReward();
  }

  /* ========== INTERNAL FUNCTIONS ========== */
  function _getReward() internal nonReentrant {
    uint amount = earned(msg.sender);

    if (amount > 0) {
      _novaToken.safeTransfer(msg.sender, amount);

      totalShares = totalShares.sub(_shares[msg.sender]);

      if (totalShares == 0) {
        _shares[msg.sender] = principalOf(msg.sender).mul(1e9);
      } else {
        uint bal = balance().sub(principalOf(msg.sender).mul(1e9));
        _shares[msg.sender] = principalOf(msg.sender).mul(1e9).mul(totalShares).div(bal);
      }

      totalShares = totalShares.add(_shares[msg.sender]);

      emit RewardsPaid(msg.sender, amount);
    }
  }

  function _addPointsToUser(address _to, uint _amount) internal nonReentrant onlyMaintainerOrOwner {
    uint _pool = balance();
    uint shares = 0;

    if (_shares[_to] == 0) {
      quantityUsers = quantityUsers.add(1);
    }

    if (totalShares == 0) {
      shares = _amount.mul(1e9);
    } else {
      shares = (_amount.mul(1e9).mul(totalShares)).div(_pool);
    }

    totalPoints = totalPoints.add(_amount);
    totalShares = totalShares.add(shares);
    _shares[_to] = _shares[_to].add(shares);
    _principal[_to] = _principal[_to].add(_amount);

    emit AddedPointsToUser(_to, _amount);
  }

  function _removePointsToUser(address user, uint _amount) internal nonReentrant onlyMaintainerOrOwner {
    uint amount = Math.min(_amount, _principal[user]);
    uint shares = Math.min(amount.mul(totalShares).div(balance()), _shares[user]);
    totalShares = totalShares.sub(shares);
    _shares[user] = _shares[user].sub(shares);
    _principal[user] = _principal[user].sub(amount);
    totalPoints = totalPoints.sub(amount);

    resetShares(user);

    if (_shares[user] == 0) {
      quantityUsers = quantityUsers.sub(1);
    }

    emit RemovePointsToUser(user, amount);
  }

  function resetShares(address user) internal {
    uint shares = _shares[user];
    if (shares > 0 && shares < 1000) {
      totalShares = totalShares.sub(shares);
      delete _shares[user];
    }
  }
}
