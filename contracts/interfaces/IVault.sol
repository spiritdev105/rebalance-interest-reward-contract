// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

import './IERC20.sol';

interface IVault is IERC20 {
  function deposit(address _account, uint _amount) external;
  function depositETH(address _account) external payable;
  function withdraw(uint _amount) external;
  function withdrawETH(uint _amount) external;
  function withdrawFrom(address _source, uint _amount) external;
  function withdrawFromETH(address _source, uint _amount) external;
  function withdrawAll() external;
  function withdrawAllETH() external;
  function pushToken(address _token, uint _amount) external;
  function setDepositsEnabled(bool _value) external;
  function addIncome(uint _addAmount) external;
  function rewardRate() external view returns(uint);
  function underlying() external view returns(address);
  function pendingAccountReward(address _account) external view returns(uint);
  function claim(address _account) external;
}