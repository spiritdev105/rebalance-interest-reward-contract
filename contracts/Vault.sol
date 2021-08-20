// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2021 0xdev0 - All rights reserved
// https://twitter.com/0xdev0

pragma solidity 0.8.6;

import './interfaces/IVaultController.sol';
import './interfaces/IVaultRebalancer.sol';

import './external/ERC20.sol';
import './external/Address.sol';
import './external/Math.sol';
import './external/ReentrancyGuard.sol';

import './TransferHelper.sol';

// Vault holds all the funds
// Rebalancer transforms the funds and can be replaced

contract Vault is TransferHelper, ReentrancyGuard, ERC20("X", "X", 18) {

  uint private constant DISTRIBUTION_PERIOD = 45_800; // ~ 7 days

  address public vaultController;
  address public underlying;

  bool private initialized;
  uint private rewardPerToken;
  uint private lastAccrualBlock;
  uint private lastIncomeBlock;
  uint private rewardRateStored;

  mapping (address => uint) private rewardSnapshot;

  event Claim(address indexed account, uint amount);
  event NewIncome(uint addAmount, uint rewardRate);
  event NewRebalancer(address indexed rebalancer);
  event Deposit(uint amount);
  event Withdraw(uint amount);

  modifier onlyRebalancer() {
    require(msg.sender == address(rebalancer()), "Vault: caller is not the rebalancer");
    _;
  }

  receive() external payable {}

  function initialize(
    address       _vaultController,
    address       _underlying,
    string memory _name
  ) external {

    require(initialized != true, "Vault: already intialized");
    initialized = true;

    vaultController = _vaultController;
    underlying      = _underlying;

    name     = _name;
    symbol   = _name;
    decimals = 18;
  }

  function depositETH(address _account) external payable nonReentrant {
    _checkEthVault();
    _depositWeth();
    _deposit(_account, msg.value);
  }

  function deposit(
    address _account,
    uint    _amount
  ) external nonReentrant {
    _safeTransferFrom(underlying, msg.sender, _amount);
    _deposit(_account, _amount);
  }

  // Withdraw from the buffer
  function withdraw(uint _amount) external nonReentrant {
    _withdraw(msg.sender, _amount);
    _safeTransfer(underlying, msg.sender, _amount);
  }

  function withdrawAll() external nonReentrant {
    uint amount = _withdrawAll(msg.sender);
    _safeTransfer(underlying, msg.sender, amount);
  }

  function withdrawAllETH() external nonReentrant {
    _checkEthVault();
    uint amount = _withdrawAll(msg.sender);
    _wethWithdrawTo(msg.sender, amount);
  }

  function withdrawETH(uint _amount) external nonReentrant {
    _checkEthVault();
    _withdraw(msg.sender, _amount);
    _wethWithdrawTo(msg.sender, _amount);
  }

  // Withdraw from a specific source
  // Call this only if the vault doesn't have enough funds in the buffer
  function withdrawFrom(
    address _source,
    uint    _amount
  ) external nonReentrant {
    _withdrawFrom(_source, _amount);
    _safeTransfer(underlying, msg.sender, _amount);
  }

  function withdrawFromETH(
    address _source,
    uint    _amount
  ) external nonReentrant {
    _checkEthVault();
    _withdrawFrom(_source, _amount);
    _wethWithdrawTo(msg.sender, _amount);
  }

  function claim(address _account) public {
    _accrue();
    uint pendingReward = pendingAccountReward(_account);

    if(pendingReward > 0) {
      _mint(_account, pendingReward);
      emit Claim(_account, pendingReward);
    }

    rewardSnapshot[_account] = rewardPerToken;
  }

  // Update rewardRateStored to distribute previous unvested income + new income
  // over te next DISTRIBUTION_PERIOD blocks
  function addIncome(uint _addAmount) external onlyRebalancer {
    _accrue();
    _safeTransferFrom(underlying, msg.sender, _addAmount);

    uint blocksElapsed  = Math.min(DISTRIBUTION_PERIOD, block.number - lastIncomeBlock);
    uint unvestedIncome = rewardRateStored * (DISTRIBUTION_PERIOD - blocksElapsed);

    rewardRateStored = (unvestedIncome + _addAmount) / DISTRIBUTION_PERIOD;
    lastIncomeBlock  = block.number;

    emit NewIncome(_addAmount, rewardRateStored);
  }

  // Push any ERC20 token to Rebalancer which will transform it and send back the LP tokens
  function pushToken(
    address _token,
    uint    _amount
  ) external onlyRebalancer {
    _safeTransfer(_token, address(rebalancer()), _amount);
  }

  function pendingAccountReward(address _account) public view returns(uint) {
    uint pedingRewardPerToken = rewardPerToken + _pendingRewardPerToken();
    uint rewardPerTokenDelta  = pedingRewardPerToken - rewardSnapshot[_account];
    return rewardPerTokenDelta * balanceOf[_account] / 1e18;
  }

  // If no new income is added for more than DISTRIBUTION_PERIOD blocks,
  // then do not distribute any more rewards
  function rewardRate() public view returns(uint) {
    uint blocksElapsed = block.number - lastIncomeBlock;

    if (blocksElapsed < DISTRIBUTION_PERIOD) {
      return rewardRateStored;
    } else {
      return 0;
    }
  }

  function rebalancer() public view returns(IVaultRebalancer) {
    return IVaultRebalancer(IVaultController(vaultController).rebalancer());
  }

  function _accrue() internal {
    rewardPerToken  += _pendingRewardPerToken();
    lastAccrualBlock = block.number;
  }

  function _deposit(address _account, uint _amount) internal {
    claim(_account);
    _mint(_account, _amount);
    _checkDepositLimit();
    emit Deposit(_amount);
  }

  function _withdraw(address _account, uint _amount) internal {
    claim(_account);
    _burn(msg.sender, _amount);
    emit Withdraw(_amount);
  }

  function _withdrawAll(address _account) internal returns(uint) {
    claim(_account);
    uint amount = balanceOf[_account];
    _burn(_account, amount);
    emit Withdraw(amount);

    return amount;
  }

  function _withdrawFrom(address _source, uint _amount) internal {
    uint selfBalance = IERC20(underlying).balanceOf(address(this));
    require(selfBalance < _amount, "Vault: unload not required");
    rebalancer().unload(address(this), _source, _amount - selfBalance);
    _withdraw(msg.sender, _amount);
  }

  function _transfer(
    address _sender,
    address _recipient,
    uint    _amount
  ) internal override {
    claim(_sender);
    claim(_recipient);
    super._transfer(_sender, _recipient, _amount);
  }

  function _pendingRewardPerToken() internal view returns(uint) {
    if (lastAccrualBlock == 0 || totalSupply == 0) {
      return 0;
    }

    uint blocksElapsed = block.number - lastAccrualBlock;
    return blocksElapsed * rewardRate() * 1e18 / totalSupply;
  }

  function _checkEthVault() internal view {
    require(
      underlying == address(WETH),
      "Vault: not ETH vault"
    );
  }

  function _checkDepositLimit() internal view {

    IVaultController vController = IVaultController(vaultController);
    uint depositLimit = vController.depositLimit(address(this));

    require(vController.depositsEnabled(), "Vault: deposits disabled");

    if (depositLimit > 0) {
      require(totalSupply <= depositLimit, "Vault: deposit limit reached");
    }
  }
}
