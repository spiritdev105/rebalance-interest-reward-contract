// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2021 0xdev0 - All rights reserved
// https://twitter.com/0xdev0

pragma solidity ^0.8.0;

import './interfaces/IController.sol';
import './external/Ownable.sol';
import './external/Address.sol';
import './external/Clones.sol';
import './LendingPair.sol';
import './TransferHelper.sol';

contract PairFactory is Ownable, TransferHelper {

  uint MAX_INT = 2**256 - 1;

  using Address for address;
  using Clones for address;

  address public lendingPairMaster;
  address public lpTokenMaster;
  IController public controller;

  mapping(address => mapping(address => address)) public pairByTokens;

  event PairCreated(address indexed pair, address indexed tokenA, address indexed tokenB);

  constructor(
    address _lendingPairMaster,
    address _lpTokenMaster,
    IController _controller
  ) {
    lendingPairMaster = _lendingPairMaster;
    lpTokenMaster = _lpTokenMaster;
    controller = _controller;
  }

  function createPair(
    address _tokenA,
    address _tokenB
  ) public returns(address) {

    require(_tokenA != _tokenB, 'PairFactory: duplicate tokens');
    require(_tokenA != address(0) && _tokenB != address(0), 'PairFactory: zero address');
    require(pairByTokens[_tokenA][_tokenB] == address(0), 'PairFactory: already exists');

    require(
      controller.tokenSupported(_tokenA) && controller.tokenSupported(_tokenB),
      "PairFactory: token not supported"
    );

    LendingPair lendingPair = LendingPair(payable(lendingPairMaster.clone()));
    lendingPair.initialize(lpTokenMaster, address(controller), IERC20(_tokenA), IERC20(_tokenB));
    pairByTokens[_tokenA][_tokenB] = address(lendingPair);
    pairByTokens[_tokenB][_tokenA] = address(lendingPair);

    emit PairCreated(address(lendingPair), _tokenA, _tokenB);

    return address(lendingPair);
  }
}
