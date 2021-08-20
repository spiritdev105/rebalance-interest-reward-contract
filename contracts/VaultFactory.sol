// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2021 0xdev0 - All rights reserved
// https://twitter.com/0xdev0

pragma solidity 0.8.6;

import './external/Ownable.sol';
import './external/Address.sol';
import './external/Clones.sol';
import './Vault.sol';

contract VaultFactory is Ownable {

  using Address for address;
  using Clones for address;

  address public vaultMaster;
  address public vaultController;

  mapping(address => address) public vaultByToken;
  mapping(address => bool)    public isVault;

  event VaultCreated(address indexed vault, address indexed token);

  constructor(
    address _vaultMaster,
    address _vaultController
  ) {
    vaultMaster     = _vaultMaster;
    vaultController = _vaultController;
  }

  function createVault(
    address       _token,
    string memory _name
  ) external onlyOwner returns(address) {

    require(_token != address(0), 'VaultFactory: zero address');
    require(vaultByToken[_token] == address(0), 'VaultFactory: already exists');

    Vault vault             = Vault(payable(vaultMaster.clone()));
    vaultByToken[_token]    = address(vault);
    isVault[address(vault)] = true;

    vault.initialize(vaultController, _token, _name);

    emit VaultCreated(address(vault), _token);

    return address(vault);
  }
}
