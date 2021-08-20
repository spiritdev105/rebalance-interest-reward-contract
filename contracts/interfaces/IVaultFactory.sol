// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

interface IVaultFactory {
  function isVault(address _vault) external view returns(bool);
}
