// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2021 0xdev0 - All rights reserved
// https://twitter.com/0xdev0

pragma solidity ^0.8.0;

import './interfaces/IERC20.sol';
import './interfaces/IFeeConverter.sol';

import './external/Ownable.sol';

contract FeeRecipient is Ownable {

  IFeeConverter public feeConverter;

  constructor(IFeeConverter _feeConverter) {
    feeConverter = _feeConverter;
  }

  function convert(
    ILendingPair _pair,
    address[] memory _path
  ) external {
    IERC20 lpToken = IERC20(_pair.lpToken(_path[0]));
    uint supplyTokenAmount = lpToken.balanceOf(address(this));
    lpToken.transfer(address(feeConverter), supplyTokenAmount);
    feeConverter.convert(msg.sender, _pair, _path, supplyTokenAmount);
  }

  function setFeeConverter(IFeeConverter _value) external onlyOwner {
    feeConverter = _value;
  }
}
