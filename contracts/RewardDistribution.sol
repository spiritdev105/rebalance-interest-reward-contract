// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import './interfaces/IERC20.sol';
import './interfaces/IPairFactory.sol';
import './interfaces/ILendingPair.sol';
import './external/Ownable.sol';

// Calling setTotalRewardPerBlock, addPool or setReward, pending rewards will be changed.
// Since all pools are likely to get accrued every hour or so, this is an acceptable deviation.
// Accruing all pools here may consume too much gas.
// up to the point of exceeding the gas limit if there are too many pools.

contract RewardDistribution is Ownable {

  struct Pool {
    address pair;
    address token;
    bool    isSupply;
    uint    points;             // How many allocation points assigned to this pool.
    uint    lastRewardBlock;    // Last block number that reward distribution occurs.
    uint    accRewardsPerToken; // Accumulated total rewards
  }

  struct PoolPosition {
    uint pid;
    bool added; // To prevent duplicates.
  }

  IPairFactory public factory;
  IERC20  public rewardToken;
  Pool[]  public pools;
  uint    public totalRewardPerBlock;
  uint    public totalPoints;

  // Pair[token][isSupply] supply = true, borrow = false
  mapping (address => mapping (address => mapping (bool => PoolPosition))) public pidByPairToken;
  // rewardSnapshot[pid][account]
  mapping (uint => mapping (address => uint)) public rewardSnapshot;

  event PoolUpdate(
    uint    indexed pid,
    address indexed pair,
    address indexed token,
    bool    isSupply,
    uint    points
  );

  event RewardRateUpdate(uint value);

  constructor(
    IPairFactory _factory,
    IERC20  _rewardToken,
    uint    _totalRewardPerBlock
  ) {
    factory = _factory;
    rewardToken = _rewardToken;
    totalRewardPerBlock = _totalRewardPerBlock;
  }

  function distributeReward(address _account, address _token) public {
    _onlyLendingPair();
    address pair = msg.sender;
    _distributeReward(_account, pair, _token, true);
    _distributeReward(_account, pair, _token, false);
  }

  function snapshotAccount(address _account, address _token, bool _isSupply) public {
    _onlyLendingPair();
    address pair = msg.sender;

    if (_poolExists(pair, _token, _isSupply)) {
      uint pid = _getPid(pair, _token, _isSupply);
      Pool memory pool = _getPool(pair, _token, _isSupply);
      rewardSnapshot[pid][_account] = pool.accRewardsPerToken * _stakedAccount(pool, _account) / 1e18;
    }
  }

  // Pending rewards will be changed. See class comments.
  function addPool(
    address _pair,
    address _token,
    bool    _isSupply,
    uint    _points
  ) public onlyOwner {

    require(
      pidByPairToken[_pair][_token][_isSupply].added == false,
      "RewardDistribution: already added"
    );

    require(
      ILendingPair(_pair).tokenA() == _token || ILendingPair(_pair).tokenB() == _token,
      "RewardDistribution: invalid token"
    );

    totalPoints += _points;

    pools.push(Pool({
      pair:     _pair,
      token:    _token,
      isSupply: _isSupply,
      points:   _points,
      lastRewardBlock: block.number,
      accRewardsPerToken: 0
    }));

    pidByPairToken[_pair][_token][_isSupply] = PoolPosition({
      pid: pools.length - 1,
      added: true
    });

    emit PoolUpdate(pools.length, _pair, _token, _isSupply, _points);
  }

  // Pending rewards will be changed. See class comments.
  function setReward(
    address _pair,
    address _token,
    bool    _isSupply,
    uint    _points
  ) public onlyOwner {

    uint pid = pidByPairToken[_pair][_token][_isSupply].pid;
    accruePool(pid);

    totalPoints = totalPoints - pools[pid].points + _points;
    pools[pid].points = _points;

    emit PoolUpdate(pid, _pair, _token, _isSupply, _points);
  }

  // Pending rewards will be changed. See class comments.
  function setTotalRewardPerBlock(uint _value) public onlyOwner {
    totalRewardPerBlock = _value;
    emit RewardRateUpdate(_value);
  }

  function accruePool(uint _pid) public {
    Pool storage pool = pools[_pid];
    pool.accRewardsPerToken += _pendingPoolReward(pool);
    pool.lastRewardBlock = block.number;
  }

  function pendingSupplyReward(address _account, address _pair, address _token) public view returns(uint) {
    if (_poolExists(_pair, _token, true)) {
      return _pendingAccountReward(_getPid(_pair, _token, true), _account);
    } else {
      return 0;
    }
  }

  function pendingBorrowReward(address _account, address _pair, address _token) public view returns(uint) {
    if (_poolExists(_pair, _token, false)) {
      return _pendingAccountReward(_getPid(_pair, _token, false), _account);
    } else {
      return 0;
    }
  }

  function pendingTokenReward(address _account, address _pair, address _token) public view returns(uint) {
    return pendingSupplyReward(_account, _pair, _token) + pendingBorrowReward(_account, _pair, _token);
  }

  function pendingAccountReward(address _account, address _pair) public view returns(uint) {
    ILendingPair pair = ILendingPair(_pair);
    return pendingTokenReward(_account, _pair, pair.tokenA()) + pendingTokenReward(_account, _pair, pair.tokenB());
  }

  function supplyBlockReward(address _pair, address _token) public view returns(uint) {
    return _poolRewardRate(_pair, _token, true);
  }

  function borrowBlockReward(address _pair, address _token) public view returns(uint) {
    return _poolRewardRate(_pair, _token, false);
  }

  function poolLength() public view returns (uint) {
    return pools.length;
  }

  // Allows to migrate rewards to a new staking contract.
  function migrateRewards(address _recipient, uint _amount) public onlyOwner {
    rewardToken.transfer(_recipient, _amount);
  }

  function _transferReward(address _to, uint _amount) internal {
    if (_amount > 0) {
      uint rewardTokenBal = rewardToken.balanceOf(address(this));
      if (_amount > rewardTokenBal) {
        rewardToken.transfer(_to, rewardTokenBal);
      } else {
        rewardToken.transfer(_to, _amount);
      }
    }
  }

  function _distributeReward(address _account, address _pair, address _token, bool _isSupply) internal {

    if (_poolExists(_pair, _token, _isSupply)) {

      uint pid = _getPid(_pair, _token, _isSupply);

      accruePool(pid);
      _transferReward(_account, _pendingAccountReward(pid, _account));
    }
  }

  function _poolRewardRate(address _pair, address _token, bool _isSupply) internal view returns(uint) {

    if (_poolExists(_pair, _token, _isSupply)) {

      Pool memory pool = _getPool(_pair, _token, _isSupply);
      return totalRewardPerBlock * pool.points / totalPoints;

    } else {
      return 0;
    }
  }

  function _pendingAccountReward(uint _pid, address _account) internal view returns(uint) {
    Pool memory pool = pools[_pid];

    uint stakedTotal = _stakedTotal(pool);

    if (stakedTotal == 0) {
      return 0;
    }

    pool.accRewardsPerToken += _pendingPoolReward(pool);
    uint stakedAccount = _stakedAccount(pool, _account);
    return pool.accRewardsPerToken * stakedAccount / 1e18 - rewardSnapshot[_pid][_account];
  }

  function _pendingPoolReward(Pool memory _pool) internal view returns(uint) {
    uint totalStaked = _stakedTotal(_pool);

    if (_pool.lastRewardBlock == 0 || totalStaked == 0) {
      return 0;
    }

    uint blocksElapsed = block.number - _pool.lastRewardBlock;
    return blocksElapsed * _poolRewardRate(_pool.pair, _pool.token, _pool.isSupply) * 1e18 / totalStaked;
  }

  function _getPool(address _pair, address _token, bool _isSupply) internal view returns(Pool memory) {
    return pools[_getPid(_pair, _token, _isSupply)];
  }

  function _getPid(address _pair, address _token, bool _isSupply) internal view returns(uint) {
    PoolPosition memory poolPosition = pidByPairToken[_pair][_token][_isSupply];
    require(poolPosition.added, "RewardDistribution: invalid pool");

    return pidByPairToken[_pair][_token][_isSupply].pid;
  }

  function _poolExists(address _pair, address _token, bool _isSupply) internal view returns(bool) {
    return pidByPairToken[_pair][_token][_isSupply].added;
  }

  function _stakedTotal(Pool memory _pool) internal view returns(uint) {
    ILendingPair pair = ILendingPair(_pool.pair);

    if (_pool.isSupply) {
      return pair.lpToken(_pool.token).totalSupply();
    } else {
      return pair.totalDebt(_pool.token);
    }
  }

  function _stakedAccount(Pool memory _pool, address _account) internal view returns(uint) {
    ILendingPair pair = ILendingPair(_pool.pair);

    if (_pool.isSupply) {
      return pair.lpToken(_pool.token).balanceOf(_account);
    } else {
      return pair.debtOf(_pool.token, _account);
    }
  }

  function _onlyLendingPair() internal view {

    if (_isContract(msg.sender)) {
      address factoryPair = factory.pairByTokens(ILendingPair(msg.sender).tokenA(), ILendingPair(msg.sender).tokenB());
      require(factoryPair == msg.sender, "RewardDistribution: caller not lending pair");

    } else {
      revert("RewardDistribution: caller not lending pair");
    }
  }

  function _isContract(address _address) internal view returns(bool isContract) {
    uint32 size;
    assembly {
      size := extcodesize(_address)
    }
    return (size > 0);
  }
}
