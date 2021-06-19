// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import './interfaces/IPriceOracle.sol';
import './external/Ownable.sol';

contract OracleAggregator is Ownable {

  IPriceOracle public linkOracle;
  IPriceOracle public uniOracle;

  event LinkOracleUpdated(address indexed oracle);
  event UniOracleUpdated(address indexed oracle);

  constructor(IPriceOracle _linkOracle, IPriceOracle _uniOracle) {
    linkOracle = _linkOracle;
    uniOracle  = _uniOracle;
  }

  function setLinkOracle(IPriceOracle _value) external onlyOwner {
    linkOracle = _value;
    emit LinkOracleUpdated(address(_value));
  }

  function setUniOracle(IPriceOracle _value) external onlyOwner {
    uniOracle = _value;
    emit UniOracleUpdated(address(_value));
  }

  function tokenPrice(address _token) external view returns(uint) {
    if (linkOracle.tokenSupported(_token)) { return linkOracle.tokenPrice(_token); }
    if (uniOracle.tokenSupported(_token)) { return uniOracle.tokenPrice(_token); }
    revert("OracleAggregator: token not supported");
  }

  function tokenSupported(address _token) external view returns(bool) {
    return linkOracle.tokenSupported(_token) || uniOracle.tokenSupported(_token);
  }
}
