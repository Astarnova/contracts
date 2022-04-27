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
import "../uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../uniswapv2/interfaces/IUniswapV2Factory.sol";
import "../uniswapv2/interfaces/IUniswapV2Pair.sol";

contract VaultPresale is Pausable, ReentrancyGuard, Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  enum StatusType {
    OPENED,
    CLOSED
  }

  event LPPaid(address indexed user, uint lp, uint week);
  event Deposit(address indexed user, uint amount);
  event Withdrawn(address indexed user, uint amount);
  event TokensReturned(address indexed user, uint amount);

  /* ========== STATE VARIABLES ========== */
  IERC20 internal _novaToken;
  IERC20 internal _stakingToken;

  uint public quantityUsers;
  uint public totalShares;
  uint public raised;
  uint public endTimeLapsus;
  uint public endTime;
  uint[] public vestingBalance = new uint[](10);
  uint[] public vestingBalanceOriginal = new uint[](10);
  uint[] public vestingBalancePeriod = new uint[](10);
  StatusType public status;
  mapping(address => bool) internal returnedTokens;
  mapping(address => uint) internal _shares;
  mapping(address => uint) internal _principal;
  mapping(address => bool[]) internal _vestingBalancePaid;

  IUniswapV2Router02 public router;
  IUniswapV2Factory public factory;

  modifier onlyOpened() {
    require(status == StatusType.OPENED, "VaultPresale: only if presale is open");
    _;
  }

  modifier onlyClosed() {
    require(status == StatusType.CLOSED, "VaultPresale: only if presale is closed");
    _;
  }

  modifier onlyEndTime() {
    require(endTime <= block.timestamp, "VaultPresale: only if endtime <= timestamp");
    _;
  }

  modifier noEndTime() {
    require(endTime == 0, "VaultPresale: The execution of the pre-sale has already started");
    _;
  }

  /* ========== CONSTRUCTOR ========== */

  constructor(address _nToken, address _sToken, uint _raised, uint _endTimeLapsus, address _router, address _factory) {
    _novaToken = IERC20(_nToken);
    _stakingToken = IERC20(_sToken);
    raised = _raised;
    status = StatusType.OPENED;
    endTimeLapsus = _endTimeLapsus;
    router = IUniswapV2Router02(_router);
    factory = IUniswapV2Factory(_factory);
  }

  /* ========== VIEW FUNCTIONS ========== */

  function balanceNova() public view returns (uint amount) {
    return _novaToken.balanceOf(address(this));
  }

  function balanceStaking() public view returns (uint amount) {
    return _stakingToken.balanceOf(address(this));
  }

  function balanceLP() public view returns (uint amount) {
    IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(address(_novaToken), address(_stakingToken)));

    return pair.balanceOf(address(this));
  }

  function sharesOf(address account) public view returns (uint) {
    return _shares[account];
  }

  function vestingBalancePaid(address account, uint week) public view returns (bool) {
    if (_vestingBalancePaid[account][week]) {
      return true;
    } else {
      return false;
    }
  }

  function principalOf(address account) public view returns (uint) {
    return _principal[account];
  }

  function lpToClaim(uint week, address account) public view returns (uint) {
    uint staked = vestingBalanceOriginal[week];

    if (_shares[account] == 0) {
      return 0;
    }

    uint percentage = _shares[account].mul(1e18).div(totalShares);

    return staked.mul(percentage).div(1e18);
  }

  function tokensToReturn() public view returns (uint) {
    if (status == StatusType.OPENED) {
      return 0;
    }

    bool returned = returnedTokens[msg.sender];

    if (returned) {
      return 0;
    }

    uint balance = totalShares.sub(raised);

    uint percentage = _shares[msg.sender].mul(1e18).div(totalShares);

    uint balanceReturned = balance.mul(percentage).div(1e18);

    return balanceReturned;
  }

  function deposit(uint _amount) external {
    _depositTo(_amount, msg.sender);
  }

  function withdrawAll() external {
    _withdraw(sharesOf(msg.sender));
  }

  function withdraw(uint amount) external {
    _withdraw(amount);
  }

  function novaToken() external view returns (address) {
    return address(_novaToken);
  }

  function getReward(uint week) external {
    _getReward(week);
  }

  function addLiquidityAndVesting() public onlyEndTime onlyOpened nonReentrant {
    status = StatusType.CLOSED;

    _stakingToken.safeApprove(address(router), raised);
    _novaToken.safeApprove(address(router), balanceNova());

    router.addLiquidity(address(_novaToken), address(_stakingToken), balanceNova(), raised, 1, 1, address(this), block.timestamp);

    IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(address(_novaToken), address(_stakingToken)));

    uint balance = pair.balanceOf(address(this)).div(10);

    for (uint i = 0; i < 10; i++) {
      vestingBalance[i] = balance;
      vestingBalanceOriginal[i] = balance;
      vestingBalancePeriod[i] = block.timestamp.add(i.add(1).mul(1 weeks));
    }
  }

  function returnTokens() public onlyClosed nonReentrant {
    uint principal = _principal[msg.sender];
    bool returned = returnedTokens[msg.sender];
    require(!returned, "VaultPresale: You have already obtained your remaining tokens");
    require(principal > 0, "VaultPresale: You have not participated in the presale");

    uint balanceReturned = tokensToReturn();

    _stakingToken.safeTransfer(msg.sender, balanceReturned);

    returnedTokens[msg.sender] = true;

    emit TokensReturned(msg.sender, balanceReturned);
  }

  /* ========== INTERNAL FUNCTIONS ========== */
  function _getReward(uint week) internal nonReentrant onlyClosed {
    uint amount = lpToClaim(week, msg.sender);
    bool paid = _vestingBalancePaid[msg.sender][week];
    uint period = vestingBalancePeriod[week];
    require(!paid, "VaultPresale: You have already claimed your tokens");
    require(amount > 0, "VaultPresale: You have no tokens to claim");
    require(block.timestamp >= period, "VaultPresale: You still can't claim your tokens");

    IERC20 pair = IERC20(factory.getPair(address(_novaToken), address(_stakingToken)));

    pair.safeTransfer(msg.sender, amount);

    _vestingBalancePaid[msg.sender][week] = true;

    vestingBalance[week] = vestingBalance[week].sub(amount);

    emit LPPaid(msg.sender, amount, week);
  }

  function _depositTo(uint _amount, address _to) internal nonReentrant whenNotPaused onlyOpened {
    uint _before = _stakingToken.balanceOf(address(this));
    _stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
    uint _after = _stakingToken.balanceOf(address(this));
    _amount = _after.sub(_before);

    totalShares = totalShares.add(_amount);
    _shares[_to] = _shares[_to].add(_amount);
    _principal[_to] = _principal[_to].add(_amount);

    returnedTokens[msg.sender] = false;

    _vestingBalancePaid[msg.sender] = new bool[](10);

    if (totalShares >= raised) {
      endTime = block.timestamp + endTimeLapsus;
    }

    emit Deposit(_to, _amount);
  }

  function _withdraw(uint _amount) internal nonReentrant onlyOpened noEndTime {
    uint amount = Math.min(_amount, _principal[msg.sender]);
    totalShares = totalShares.sub(amount);
    _shares[msg.sender] = _shares[msg.sender].sub(amount);
    _principal[msg.sender] = _principal[msg.sender].sub(amount);

    _stakingToken.safeTransfer(msg.sender, amount);

    emit Withdrawn(msg.sender, amount);
  }
}
