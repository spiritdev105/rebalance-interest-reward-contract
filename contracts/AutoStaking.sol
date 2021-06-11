// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import './interfaces/IERC20.sol';
import './external/ERC20.sol';

contract AutoStaking is ERC20("xWILD", "xWILD", 18) {

  IERC20 public wild;

  event Deposit(uint wildAmount, uint shareAmount);
  event Withdraw(uint wildAmount, uint shareAmount);

  constructor(IERC20 _wild) {
    wild = _wild;
  }

  function deposit(uint _wildAmount) public {
    uint poolWILD = wild.balanceOf(address(this));
    uint shareAmount;

    if (totalSupply == 0 || poolWILD == 0) {
      _mint(msg.sender, _wildAmount);
    } else {
      shareAmount = _wildAmount * totalSupply / poolWILD;
      _mint(msg.sender, shareAmount);
    }

    wild.transferFrom(msg.sender, address(this), _wildAmount);

    emit Deposit(_wildAmount, shareAmount);
  }

  function withdraw(uint _share) public {
    uint wildAmount = _share * wild.balanceOf(address(this)) / totalSupply;
    _burn(msg.sender, _share);
    wild.transfer(msg.sender, wildAmount);

    emit Deposit(wildAmount, _share);
  }
}