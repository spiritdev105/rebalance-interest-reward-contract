// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

interface IUniswapV2Factory {

  function getPair(address _fromToken, address _toToken) external view returns(address);
  function createPair(address tokenA, address tokenB) external returns (address pair);
}
