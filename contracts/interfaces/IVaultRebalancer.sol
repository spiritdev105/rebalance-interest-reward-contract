// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

interface IVaultRebalancer {
  function unload(address _vault, address _pair, uint _amount) external;
  function distributeIncome(address _vault) external;
  function pairDeposits(address _pair) external view returns(uint);
}