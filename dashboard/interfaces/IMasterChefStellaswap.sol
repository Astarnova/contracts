// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMasterChefStellaswap {
  function totalAllocPoint() external view returns (uint256);

  function deposit(uint256 _pid, uint256 _amount) external;

  function poolLength() external view returns (uint256);

  function stellaPerBlock() external view returns (uint256);

  function poolTotalLp(uint256 pid) external view returns (uint256);

  // Percentage of pool rewards that goto the team.
  function teamPercent() external view returns (uint256);

  // Percentage of pool rewards that goes to the treasury.
  function treasuryPercent() external view returns (uint256);

  // Percentage of pool rewards that goes to the investor.
  function investorPercent() external view returns (uint256);

  function poolInfo(uint _pid) view external returns (
    address lpToken, // Address of LP token contract.
    uint256 allocPoint, // How many allocation points assigned to this pool. Stella to distribute per block.
    uint256 lastRewardBlock, // Last block number that Stella distribution occurs.
    uint256 accStellaPerShare, // Accumulated Stella per share, times 1e12. See below.
    uint16 depositFeeBP, // Deposit fee in basis points
    uint256 harvestInterval, // Harvest interval in seconds
    uint256 totalLp // Total token in Pool
  );

  function userInfo(uint _pid, address _account) view external returns (
    uint256 amount, // How many LP tokens the user has provided.
    uint256 rewardDebt, // Reward debt. See explanation below.
    uint256 rewardLockedUp, // Reward locked up.
    uint256 nextHarvestUntil // When can the user harvest again.
  );

  function withdraw(uint256 _pid, uint256 _amount) external;
}
