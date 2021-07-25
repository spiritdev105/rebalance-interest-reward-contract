// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2021 0xdev0 - All rights reserved
// https://twitter.com/0xdev0

pragma solidity 0.8.6;

import './interfaces/IERC20.sol';
import './interfaces/ISwapRouter.sol';
import './interfaces/ILendingPair.sol';
import './interfaces/IController.sol';

import './external/Ownable.sol';
import './external/BytesLib.sol';

contract FeeConverter is Ownable {

  using BytesLib for bytes;


  uint private constant MAX_INT = 2**256 - 1;

  // Only large liquid tokens: ETH, DAI, USDC, WBTC, etc
  mapping (address => bool) public permittedTokens;

  ISwapRouter public immutable uniswapRouter;
  IERC20         public wildToken;
  IController    public controller;
  address        public stakingPool;
  uint           public callIncentive;

  event FeeDistribution(uint amount);

  constructor(
    ISwapRouter _uniswapRouter,
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
    address          _incentiveRecipient,
    ILendingPair     _pair,
    bytes memory     _path,
    uint             _supplyTokenAmount
  ) external {

    _validatePath(_path);
    require(_pair.controller() == controller, "FeeConverter: invalid pair");
    require(_supplyTokenAmount > 0, "FeeConverter: nothing to convert");

    address supplyToken = _path.toAddress(0);

    _pair.withdraw(supplyToken, _supplyTokenAmount);
    IERC20(supplyToken).approve(address(uniswapRouter), MAX_INT);

    uniswapRouter.exactInput(
      ISwapRouter.ExactInputParams(
        _path,
        address(this),
        block.timestamp + 1000,
        _supplyTokenAmount,
        0
      )
    );

    uint wildBalance = wildToken.balanceOf(address(this));
    uint callerIncentive = wildBalance * callIncentive / 100e18;
    wildToken.transfer(_incentiveRecipient, callerIncentive);
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

  function _validatePath(bytes memory _path) internal view {

    // check last token
    require(_path.toAddress(_path.length-20) == address(wildToken), "FeeConverter: must convert into WILD");

    uint numPools = ((_path.length - 20) / 23);

    // Validate only middle tokens. Skip the first and last token.
    for (uint8 i = 1; i < numPools; i++) {
      _validateToken(_path, i);
    }

  }

  function _validateToken(bytes memory _path, uint8 position) internal view {
    address token = _path.slice(23*position, _path.length - 23*position).toAddress(0);
    require(permittedTokens[token], "FeeConverter: invalid path");
  }

}
