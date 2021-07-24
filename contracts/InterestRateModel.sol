// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2021 0xdev0 - All rights reserved
// https://twitter.com/0xdev0

pragma solidity 0.8.6;

import './interfaces/ILendingPair.sol';
import './interfaces/IERC20.sol';

import './external/Math.sol';
import './external/Ownable.sol';

contract InterestRateModel is Ownable {

  // InterestRateModel can be re-deployed later
  uint private constant BLOCK_TIME = 132e17; // 13.2 seconds

  // Per block
  uint public minRate;
  uint public lowRate;
  uint public highRate;
  uint public targetUtilization; // 80e18 = 80%
  uint public systemRateDefault; // 50e18 - share of fees earned by the system

  event NewMinRate(uint value);
  event NewLowRate(uint value);
  event NewHighRate(uint value);
  event NewTargetUtilization(uint value);
  event NewSystemRateDefault(uint value);

  constructor(
    uint _minRate,
    uint _lowRate,
    uint _highRate,
    uint _targetUtilization,
    uint _systemRateDefault
  ) {
    minRate           = _timeRateToBlockRate(_minRate);
    lowRate           = _timeRateToBlockRate(_lowRate);
    highRate          = _timeRateToBlockRate(_highRate);
    targetUtilization = _targetUtilization;
    systemRateDefault = _systemRateDefault;
  }

  function setMinRate(uint _value) external onlyOwner {
    require(_value < lowRate, "InterestRateModel: _value < lowRate");
    minRate = _timeRateToBlockRate(_value);
    emit NewMinRate(_value);
  }

  function setLowRate(uint _value) external onlyOwner {
    require(_value < highRate, "InterestRateModel: _value < lowRate");
    lowRate = _timeRateToBlockRate(_value);
    emit NewLowRate(_value);
  }

  function setHighRate(uint _value) external onlyOwner {
    highRate = _timeRateToBlockRate(_value);
    emit NewHighRate(_value);
  }

  function setTargetUtilization(uint _value) external onlyOwner {
    require(_value < 99e18, "InterestRateModel: _value < 100e18");
    targetUtilization = _value;
    emit NewTargetUtilization(_value);
  }

  function setSystemRate(uint _value) external onlyOwner {
    require(_value < 100e18, "InterestRateModel: _value < 100e18");
    systemRateDefault = _value;
    emit NewSystemRateDefault(_value);
  }

  function supplyRatePerBlock(ILendingPair _pair, address _token) external view returns(uint) {
    return borrowRatePerBlock(_pair, _token) * (100e18 - systemRateDefault) / 100e18;
  }

  function borrowRatePerBlock(ILendingPair _pair, address _token) public view returns(uint) {
    uint debt = _pair.totalDebt(_token);
    uint supply = IERC20(_pair.lpToken(_token)).totalSupply();

    if (supply == 0 || debt == 0) { return minRate; }

    uint utilization = (debt * 100e18 / supply) * 100e18 / targetUtilization;

    if (utilization < 100e18) {
      uint rate = lowRate * utilization / 100e18;
      return Math.max(rate, minRate);
    } else {
      utilization = 100e18 * ( debt - (supply * targetUtilization / 100e18) ) / (supply * (100e18 - targetUtilization) / 100e18);
      utilization = Math.min(utilization, 100e18);
      return lowRate + (highRate - lowRate) * utilization / 100e18;
    }
  }

  function utilizationRate(ILendingPair _pair, address _token) external view returns(uint) {
    uint debt = _pair.totalDebt(_token);
    uint supply = IERC20(_pair.lpToken(_token)).totalSupply();

    if (supply == 0 || debt == 0) { return 0; }

    return Math.min(debt * 100e18 / supply, 100e18);
  }

  // InterestRateModel can later be replaced for more granular fees per _lendingPair
  function systemRate(ILendingPair _pair, address _token) external view returns(uint) {
    return systemRateDefault;
  }

  // _uint is set as 1e18 = 1% (annual) and converted to the block rate
  function _timeRateToBlockRate(uint _uint) private view returns(uint) {
    return _uint / 365 / 86400 * BLOCK_TIME / 1e18;
  }
}
