// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

interface IRewardDistribution {

  function distributeReward(address _account, address _token) external;
  function setTotalRewardPerBlock(uint _value) external;
  function migrateRewards(address _recipient, uint _amount) external;

  function addPool(
    address _pair,
    address _token,
    bool    _isSupply,
    uint    _points
  ) external;

  function setReward(
    address _pair,
    address _token,
    bool    _isSupply,
    uint    _points
  ) external;
}
