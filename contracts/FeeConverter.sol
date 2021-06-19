// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2021 0xdev0 - All rights reserved
// https://twitter.com/0xdev0

pragma solidity ^0.8.0;

import './interfaces/IERC20.sol';
import './interfaces/IUniswapRouter.sol';
import './interfaces/ILendingPair.sol';
import './interfaces/IController.sol';

import './external/Ownable.sol';

contract FeeConverter is Ownable {

  uint MAX_INT = 2**256 - 1;

  // Only large liquid tokens: ETH, DAI, USDC, WBTC, etc
  mapping (address => bool) public permittedTokens;

  IUniswapRouter public uniswapRouter;
  IERC20         public wildToken;
  IController    public controller;
  address        public stakingPool;
  uint           public callIncentive;

  event FeeDistribution(uint amount);

  constructor(
    IUniswapRouter _uniswapRouter,
    IController    _controller,
    IERC20         _wildToken,
    address        _stakingPool,
    uint           _callIncentive
  ) {
    uniswapRouter = _uniswapRouter;
    controller    = _controller;
    stakingPool   = _stakingPool;
    callIncentive = _callIncentive;
    wildToken     = _wildToken;
  }

  function convert(
    address          _sender,
    ILendingPair     _pair,
    address[] memory _path,
    uint             _supplyTokenAmount
  ) external {

    _validatePath(_path);
    require(_pair.controller() == controller, "FeeConverter: invalid pair");
    require(_supplyTokenAmount > 0, "FeeConverter: nothing to convert");

    _pair.withdraw(_path[0], _supplyTokenAmount);
    IERC20(_path[0]).approve(address(uniswapRouter), MAX_INT);

    uniswapRouter.swapExactTokensForTokens(
      _supplyTokenAmount,
      0,
      _path,
      address(this),
      block.timestamp + 1000
    );

    uint wildBalance = wildToken.balanceOf(address(this));
    uint callerIncentive = wildBalance * callIncentive / 100e18;
    wildToken.transfer(_sender, callerIncentive);
    wildToken.transfer(stakingPool, wildBalance - callerIncentive);

    emit FeeDistribution(wildBalance - callerIncentive);
  }

  function setStakingRewards(address _value) external onlyOwner {
    stakingPool = _value;
  }

  function setController(IController _value) external onlyOwner {
    controller = _value;
  }

  function setCallIncentive(uint _value) external onlyOwner {
    callIncentive = _value;
  }

  function permitToken(address _token, bool _value) external onlyOwner {
    permittedTokens[_token] = _value;
  }

  function _validatePath(address[] memory _path) internal view {
    require(_path[_path.length - 1] == address(wildToken), "FeeConverter: must convert into WILD");

    // Validate only middle tokens. Skip the first and last token.
    for (uint i; i < _path.length - 1; i++) {
      if (i > 0) {
        require(permittedTokens[_path[i]], "FeeConverter: invalid path");
      }
    }
  }
}
