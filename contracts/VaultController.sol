// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

import './external/Address.sol';
import './external/Ownable.sol';

contract VaultController is Ownable {

  using Address for address;

  address public rebalancer;
  bool    public depositsEnabled;

  mapping(address => bool) public isGuardian;
  mapping(address => uint) public depositLimit;

  event NewDepositLimit(address indexed vault, uint amount);
  event DepositsEnabled(bool value);
  event NewRebalancer(address indexed rebalancer);
  event AllowGuardian(address indexed guardian, bool value);

  modifier onlyGuardian() {
    require(isGuardian[msg.sender], "VaultController: caller is not a guardian");
    _;
  }

  constructor() {
    depositsEnabled = true;
  }

  function setRebalancer(address _rebalancer) external onlyOwner {
    _requireContract(_rebalancer);
    rebalancer = _rebalancer;
    emit NewRebalancer(_rebalancer);
  }

  // Allow immediate emergency shutdown of deposits by the guardian.
  function disableDeposits() external onlyGuardian {
    depositsEnabled = false;
    emit DepositsEnabled(false);
  }

  // Re-enabling deposits can only be done by the owner
  function enableDeposits() external onlyOwner {
    depositsEnabled = true;
    emit DepositsEnabled(true);
  }

  function setDepositLimit(address _vault, uint _amount) external onlyOwner {
    _requireContract(_vault);
    depositLimit[_vault] = _amount;
    emit NewDepositLimit(_vault, _amount);
  }

  function allowGuardian(address _guardian, bool _value) external onlyOwner {
    isGuardian[_guardian] = _value;
    emit AllowGuardian(_guardian, _value);
  }

  function _requireContract(address _value) internal view {
    require(_value.isContract(), "VaultController: must be a contract");
  }
}
