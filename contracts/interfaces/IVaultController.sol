// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

interface IVaultController {
  function depositsEnabled() external view returns(bool);
  function setDepositLimit(address _vault, uint _amount) external;
  function depositLimit(address _vault) external view returns(uint);
  function setRebalancer(address _rebalancer) external;
  function rebalancer() external view returns(address);
}
