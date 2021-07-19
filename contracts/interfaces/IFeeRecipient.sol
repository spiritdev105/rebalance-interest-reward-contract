// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

import './IFeeConverter.sol';

interface IFeeRecipient {
  function setFeeConverter(IFeeConverter _value) external;
}
