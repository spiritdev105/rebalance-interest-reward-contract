// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import './interfaces/IInterestRateModel.sol';
import './interfaces/IRewardDistribution.sol';
import './interfaces/IPriceOracle.sol';
import './external/Ownable.sol';

contract Controller is Ownable {

  uint public constant LIQ_MIN_HEALTH = 15e17; // 1.5

  IInterestRateModel  public interestRateModel;
  IPriceOracle        public priceOracle;
  IRewardDistribution public rewardDistribution;

  bool public depositsEnabled;
  uint public liqFeeCallerDefault;
  uint public liqFeeSystemDefault;

  mapping(address => mapping(address => uint)) public depositLimit;
  mapping(address => uint) public liqFeeCallerToken; // 1e18  = 1%
  mapping(address => uint) public liqFeeSystemToken; // 1e18  = 1%
  mapping(address => uint) public colFactor; // 90e18 = 90%

  address public feeRecipient;

  event NewFeeRecipient(address feeRecipient);
  event NewInterestRateModel(address interestRateModel);
  event NewPriceOracle(address priceOracle);
  event NewRewardDistribution(address rewardDistribution);
  event NewColFactor(address token, uint value);
  event NewDepositLimit(address pair, address token, uint value);
  event DepositsEnabled(bool value);
  event NewLiqParamsToken(address token, uint liqFeeSystem, uint liqFeeCaller);
  event NewLiqParamsDefault(uint liqFeeSystem, uint liqFeeCaller);

  constructor(
    IInterestRateModel _interestRateModel,
    uint _liqFeeSystemDefault,
    uint _liqFeeCallerDefault
  ) {
    feeRecipient = msg.sender;
    interestRateModel = _interestRateModel;
    liqFeeSystemDefault = _liqFeeSystemDefault;
    liqFeeCallerDefault = _liqFeeCallerDefault;
    depositsEnabled = true;
  }

  function setFeeRecipient(address _feeRecipient) public onlyOwner {
    feeRecipient = _feeRecipient;
    emit NewFeeRecipient(_feeRecipient);
  }

  function setLiqParamsToken(
    address _token,
    uint    _liqFeeSystem,
    uint    _liqFeeCaller
  ) public onlyOwner {
    // Never more than a total of 50%
    require(_liqFeeCaller + _liqFeeSystem <= 50e18, "PairFactory: fees too high");

    liqFeeSystemToken[_token] = _liqFeeSystem;
    liqFeeCallerToken[_token] = _liqFeeCaller;

    emit NewLiqParamsToken(_token, _liqFeeSystem, _liqFeeCaller);
  }

  function setLiqParamsDefault(
    uint    _liqFeeSystem,
    uint    _liqFeeCaller
  ) public onlyOwner {
    // Never more than a total of 50%
    require(_liqFeeCaller + _liqFeeSystem <= 50e18, "PairFactory: fees too high");

    liqFeeSystemDefault = _liqFeeSystem;
    liqFeeCallerDefault = _liqFeeCaller;

    emit NewLiqParamsDefault(_liqFeeSystem, _liqFeeCaller);
  }

  function setInterestRateModel(IInterestRateModel _value) public onlyOwner {
    interestRateModel = _value;
    emit NewInterestRateModel(address(_value));
  }

  function setPriceOracle(IPriceOracle _oracle) public onlyOwner {
    priceOracle = _oracle;
    emit NewPriceOracle(address(_oracle));
  }

  function setRewardDistribution(IRewardDistribution _value) public onlyOwner {
    rewardDistribution = _value;
    emit NewRewardDistribution(address(_value));
  }

  function setDepositsEnabled(bool _value) public onlyOwner {
    depositsEnabled = _value;
    emit DepositsEnabled(_value);
  }

  function setDepositLimit(address _pair, address _token, uint _value) public onlyOwner {
    depositLimit[_pair][_token] = _value;
    emit NewDepositLimit(_pair, _token, _value);
  }

  function setColFactor(address _token, uint _value) public onlyOwner {
    colFactor[_token] = _value;
    emit NewColFactor(_token, _value);
  }

  function liqFeesTotal(address _token) public view returns(uint) {
    return liqFeeSystem(_token) + liqFeeCaller(_token);
  }

  function liqFeeSystem(address _token) public view returns(uint) {
    return liqFeeSystemToken[_token] > 0 ? liqFeeSystemToken[_token] : liqFeeSystemDefault;
  }

  function liqFeeCaller(address _token) public view returns(uint) {
    return liqFeeCallerToken[_token] > 0 ? liqFeeCallerToken[_token] : liqFeeCallerDefault;
  }

  function tokenPrice(address _token) public view returns(uint) {
    return priceOracle.tokenPrice(_token);
  }

  function tokenSupported(address _token) public view returns(bool) {
    return priceOracle.tokenSupported(_token);
  }
}
