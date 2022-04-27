// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMasterChef {
  function totalAllocPoint() external view returns (uint256);

  function deposit(uint256 _pid, uint256 _amount) external;

  function poolLength() external view returns (uint256);

  function novaPerSec() external view returns (uint256);

  function poolTotalLp(uint256 pid) external view returns (uint256);

  function poolInfo(uint _pid) view external returns (
    address lpToken, // Address of LP token contract.
    uint256 allocPoint, // How many allocation points assigned to this pool. Nova to distribute per block.
    uint256 lastRewardTimestamp, // Last block number that Nova distribution occurs.
    uint256 accNovaPerShare, // Accumulated Nova per share, times 1e18. See below.
    uint16 depositFeeBP, // Deposit fee in basis points
    uint256 harvestInterval, // Harvest interval in seconds
    uint256 totalLp
  );

  function poolRewardsPerSec(uint256 _pid) external view returns (
    address[] memory addresses,
    string[] memory symbols,
    uint256[] memory decimals,
    uint256[] memory rewardsPerSec
  );

  function userInfo(uint _pid, address _account) view external returns (
    uint256 amount, // How many LP tokens the user has provided.
    uint256 rewardDebt, // Reward debt. See explanation below.
    uint256 rewardLockedUp, // Reward locked up.
    uint256 nextHarvestUntil // When can the user harvest again.
  );

  function withdraw(uint256 _pid, uint256 _amount) external;
}
