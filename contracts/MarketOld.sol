pragma solidity 0.5.7;

import "./external/openzeppelin-solidity/math/SafeMath.sol";
import "./external/oraclize/ethereum-api/usingOraclize.sol";
import "./config/MarketConfig.sol";
contract IPlotus {

    enum MarketType {
      HourlyMarket,
      DailyMarket,
      WeeklyMarket
    }
    address public owner;
    function() external payable{}
    function callPlacePredictionEvent(address _user,uint _value, uint _predictionPoints, uint _prediction) public{
    }
    function callClaimedEvent(address _user , uint _reward, uint _stake) public {
    }
    function callMarketResultEvent(uint _commision, uint _donation) public {
    }
    function withdraw(uint amount) external {
    }
}
contract Market is usingOraclize {
    using SafeMath for uint;

    enum PredictionStatus {
      Started,
      Closed,
      ResultDeclared
    }
  
    uint internal startTime;//
    uint internal expireTime;//
    string internal FeedSource;//
    uint internal rate; //*
    // uint public currentPrice; //*
    uint internal currentPriceLocation;
    uint internal totalReward;//
    bytes32 internal marketResultId;
    uint internal rewardToDistribute;
    PredictionStatus internal predictionStatus;//
    uint public predictionForDate;//
    
    mapping(address => mapping(uint=>uint)) internal ethStaked;
    mapping(address => mapping(uint => uint)) internal userPredictionPoints;
    mapping(address => bool) internal userClaimedReward;
    
    IPlotus internal pl;
    MarketConfig internal marketConfig;
    
    struct option
    {
      uint minValue;
      uint maxValue;
      uint predictionPoints;
      uint ethStaked;
    }

    mapping(uint=>option) public optionsAvailable;

    modifier OnlyOwner() {
      require(msg.sender == pl.owner() || msg.sender == address(pl));
      _;
    }

    function initiate(
     uint[] memory _uintparams,
     string memory _feedsource,
     address marketConfigs
    ) 
    public 
    {
      pl = IPlotus(msg.sender);
      marketConfig = MarketConfig(marketConfigs);
      startTime = _uintparams[0];
      FeedSource = _feedsource;
      predictionForDate = _uintparams[1];
      rate = _uintparams[2];
      optionsAvailable[0] = option(0,0,0,0);
      (uint predictionTime, , , , , , ) = marketConfig.getPriceCalculationParams();
      expireTime = startTime + predictionTime;
      require(expireTime > now);

      // currentPrice = _uintparams[6];
      setOptionRanges(_uintparams[3]);
      setCurrentPrice(_uintparams[3]);
      // currentPriceLocation = _getDistance(OPTION_START_INDEX) + 1;
      // _setPrice();
      // closeMarketId = oraclize_query(expireTime.sub(now), "", "");
      oraclize_query(expireTime.sub(now).add(predictionForDate), "URL", "json(https://financialmodelingprep.com/api/v3/majors-indexes/.DJI).price");
    }

    function () external payable {
      revert("Can be deposited only through placePrediction");
    }

    function marketStatus() internal view returns(PredictionStatus){
      if(predictionStatus == PredictionStatus.Started && now >= expireTime) {
        return PredictionStatus.Closed;
      }
      return predictionStatus;
    }

    //Need to add check Only Admin or Any authorized address
    function setCurrentPrice(uint _currentPrice) public OnlyOwner {
      require(now <= expireTime, "prediction closed");
      // require(predictionStatus == PredictionStatus.Started,"bet closed");
      // currentPrice = _currentPrice;
      currentPriceLocation = _getCPDistanceFromFirstOption(_currentPrice);
    }

    function _calculateOptionPrice(uint _option, uint _totalStaked, uint _ethStakedOnOption, uint _totalOptions) internal view returns(uint _optionPrice) {
      _optionPrice = 0;
      (uint predictionTime,uint optionStartIndex,uint stakeWeightage,uint stakeWeightageMinAmount,uint predictionWeightage,uint minTimeElapsed,  ) = marketConfig.getPriceCalculationParams();
      if(now > expireTime) {
        return 0;
      }
      if(_totalStaked > stakeWeightageMinAmount) {
        _optionPrice = (_ethStakedOnOption).mul(1000000)
                      .div(_totalStaked.mul(stakeWeightage));
      }

      uint distance = currentPriceLocation > _option ? currentPriceLocation.sub(_option) : _option.sub(currentPriceLocation);
      uint maxDistance = currentPriceLocation > (_totalOptions.div(2))? (currentPriceLocation.sub(optionStartIndex)): (_totalOptions.sub(currentPriceLocation));
      // uint maxDistance = 7 - (_option > distance ? _option - distance: _option + distance);
      uint timeElapsed = now > startTime ? now.sub(startTime) : 0;
      timeElapsed = timeElapsed > minTimeElapsed ? timeElapsed: minTimeElapsed;
      _optionPrice = _optionPrice.add((
              ((maxDistance+1).sub(distance)).mul(1000000).mul(timeElapsed)
             )
             .div(
              (maxDistance+1).mul(predictionWeightage).mul(predictionTime)
             ));
      _optionPrice = _optionPrice.div(100);
    }

    /**
    * @dev Get Current price distance from first option 
    */
    function _getCPDistanceFromFirstOption(uint _currentPrice) internal view returns(uint _distance) {
      (, uint optionStartIndex, , , , , uint delta) = marketConfig.getPriceCalculationParams();
      (, uint totalOptions, , , , ) = marketConfig.getBasicMarketDetails();
      if(_currentPrice > optionsAvailable[totalOptions].minValue) {
        _distance = totalOptions - optionStartIndex;
      } else if(_currentPrice < optionsAvailable[optionStartIndex].maxValue) {
        _distance = 0;
      } else if(_currentPrice > optionsAvailable[optionStartIndex].maxValue) {
        _distance = 1;
      }
    }

    function setOptionRanges(uint _currentPrice) internal{
      (, , , , , , uint delta) = marketConfig.getPriceCalculationParams();
        (, uint totalOptions, , , , ) = marketConfig.getBasicMarketDetails();
     // uint primaryOption = totalOptions.div(2).add(1);
     
     // optionsAvailable[primaryOption].minValue = _currentPrice.sub(uint(delta).div(2));
      //optionsAvailable[primaryOption].maxValue = _currentPrice.add(uint(delta).div(2));
      //uint _increaseOption;
    //   for(uint i = primaryOption ;i>1 ;i--){
    //     _increaseOption = ++primaryOption;
    //     if(i-1 > 1){
    //       optionsAvailable[i-1].maxValue = optionsAvailable[i].minValue.sub(1);
    //       optionsAvailable[i-1].minValue = optionsAvailable[i].minValue.sub(delta);
    //       optionsAvailable[_increaseOption].maxValue = optionsAvailable[_increaseOption-1].maxValue.add(delta);
    //       optionsAvailable[_increaseOption].minValue = optionsAvailable[_increaseOption-1].maxValue.add(1);
    //     }
    //     else{
    //       optionsAvailable[i-1].maxValue = optionsAvailable[i].minValue.sub(1);
    //       optionsAvailable[i-1].minValue = 0;
    //       //Max uint value
    //       optionsAvailable[_increaseOption].maxValue = ~uint256(0);
    //       optionsAvailable[_increaseOption].minValue = optionsAvailable[_increaseOption-1].maxValue.add(1);
    //     }
    //   }
     optionsAvailable[1].minValue = 0;
     optionsAvailable[1].maxValue = _currentPrice.sub(1);
     optionsAvailable[2].minValue = _currentPrice;
     optionsAvailable[2].maxValue = _currentPrice.add(200);
     optionsAvailable[3].minValue = _currentPrice.add(1);
     optionsAvailable[3].maxValue = ~uint256(0);
     
    }

    function getPrice(uint _prediction) external view returns(uint) {
      (, uint totalOptions, , , , ) = marketConfig.getBasicMarketDetails();
     return _calculateOptionPrice(_prediction, address(this).balance, optionsAvailable[_prediction].ethStaked, totalOptions);
    }

    function getData() public view returns
       (string memory _feedsource,uint[] memory minvalue,uint[] memory maxvalue,
        uint[] memory _optionPrice, uint[] memory _ethStaked,uint _predictionType,uint _expireTime, uint _predictionStatus){
        uint totalOptions;
        (_predictionType, totalOptions, , , , ) = marketConfig.getBasicMarketDetails();
        _feedsource = FeedSource;
        _expireTime =expireTime;
        _predictionStatus = uint(marketStatus());
        minvalue = new uint[](totalOptions);
        maxvalue = new uint[](totalOptions);
        _optionPrice = new uint[](totalOptions);
        _ethStaked = new uint[](totalOptions);
       for (uint i = 0; i < totalOptions; i++) {
        _ethStaked[i] = optionsAvailable[i+1].ethStaked;
        minvalue[i] = optionsAvailable[i+1].minValue;
        maxvalue[i] = optionsAvailable[i+1].maxValue;
        _optionPrice[i] = _calculateOptionPrice(i+1, address(this).balance, optionsAvailable[i+1].ethStaked, totalOptions);
       }
    }

    function estimatePredictionValue(uint _prediction, uint _stake) public view returns(uint _predictionValue){
      (, uint totalOptions, , uint priceStep , , ) = marketConfig.getBasicMarketDetails();
      return _calculatePredictionValue(_prediction, _stake, address(this).balance, priceStep, totalOptions);
    }

    function _calculatePredictionValue(uint _prediction, uint _stake, uint _totalContribution, uint _priceStep, uint _totalOptions) internal view returns(uint _predictionValue) {
      uint value;
      uint flag = 0;
      uint _ethStakedOnOption = optionsAvailable[_prediction].ethStaked;
      _predictionValue = 0;
      while(_stake > 0) {
        if(_stake <= (_priceStep)) {
          value = (uint(_stake)).div(rate);
          _predictionValue = _predictionValue.add(value.mul(10**6).div(_calculateOptionPrice(_prediction, _totalContribution, _ethStakedOnOption + flag.mul(_priceStep), _totalOptions)));
          break;
        } else {
          _stake = _stake.sub(_priceStep);
          value = (uint(_priceStep)).div(rate);
          _predictionValue = _predictionValue.add(value.mul(10**6).div(_calculateOptionPrice(_prediction, _totalContribution, _ethStakedOnOption + flag.mul(_priceStep), _totalOptions)));
          _totalContribution = _totalContribution.add(_priceStep);
          flag++;
        }
      } 
    }

    function placePrediction(uint _prediction) public payable {
      require(now >= startTime && now <= expireTime);
      (, uint totalOptions, uint minPrediction, uint priceStep, , ) = marketConfig.getBasicMarketDetails();
      require(msg.value >= minPrediction,"Min prediction amount required");
      uint _totalContribution = address(this).balance.sub(msg.value);
      uint predictionValue = _calculatePredictionValue(_prediction, msg.value, _totalContribution, priceStep, totalOptions);
      require(predictionValue > 0, "Stake too low");
      userPredictionPoints[msg.sender][_prediction] = userPredictionPoints[msg.sender][_prediction].add(predictionValue);
      ethStaked[msg.sender][_prediction] = ethStaked[msg.sender][_prediction].add(msg.value);
      optionsAvailable[_prediction].predictionPoints = optionsAvailable[_prediction].predictionPoints.add(predictionValue);
      optionsAvailable[_prediction].ethStaked = optionsAvailable[_prediction].ethStaked.add(msg.value);

      pl.callPlacePredictionEvent(msg.sender,msg.value, predictionValue, _prediction);
    }

    // function _closeBet() public {      
    //   //Bet will be closed by oraclize address
    //   // require (msg.sender == oraclize_cbAddress());
      
    //   require(predictionStatus == PredictionStatus.Started && now >= expireTime,"bet not yet expired");
      
    //   predictionStatus = PredictionStatus.Closed;
    //   pl.callCloseMarketEvent(betType);
    //   if(now >= expireTime.add(predictionForDate)) {
    //     predictionForDate = 0;
    //   } else {
    //     predictionForDate.sub(now.sub(expireTime));
    //   }
    //   marketResultId = oraclize_query(predictionForDate, "URL", "json(https://financialmodelingprep.com/api/v3/majors-indexes/.DJI).price");
    // }

    function calculatePredictionResult(uint _value) public {
      require(msg.sender == pl.owner() || msg.sender == oraclize_cbAddress());
      require(now >= expireTime.add(predictionForDate),"Time not reached");

      require(_value > 0);
      (, uint totalOptions, , , , uint bonuReturnPerc) = marketConfig.getBasicMarketDetails();
      (, uint optionStartIndex, , , , , ) = marketConfig.getPriceCalculationParams();

      predictionStatus = PredictionStatus.ResultDeclared;
      for(uint i=optionStartIndex;i <= totalOptions;i++){
        if(_value <= optionsAvailable[i].maxValue && _value >= optionsAvailable[i].minValue){
          // WinningOption = i;
          currentPriceLocation = i;
        }         
        else{
          totalReward = totalReward.add(optionsAvailable[i].ethStaked);
        }
      }
      //Get donation, commission addresses and percentage
      (address payable donationAccount, uint donation, address payable commissionAccount, uint commission) = marketConfig.getFundDistributionParams();
      if(optionsAvailable[currentPriceLocation].ethStaked > 0 && totalReward > 0){
        // when  some wins some losses.
        commission = commission.mul(totalReward).div(100);
        donation = donation.mul(totalReward).div(100);
        rewardToDistribute = totalReward.sub(commission).sub(donation);
        _transferEther(commissionAccount, commission);
        _transferEther(donationAccount, donation);
      } else if(optionsAvailable[currentPriceLocation].ethStaked > 0 && totalReward == 0){
        // when all win.
        commission = 0;
        donation = 0;
        rewardToDistribute = 0;
        //Extra 2 decimals were added to percentage
        if(address(pl).balance > (optionsAvailable[currentPriceLocation].ethStaked.mul(bonuReturnPerc)).div(10000)) {
          pl.withdraw((optionsAvailable[currentPriceLocation].ethStaked.mul(bonuReturnPerc)).div(10000));
        }
      } else if(optionsAvailable[currentPriceLocation].ethStaked == 0 && totalReward > 0){
        // when all looses. 
        commission = commission.mul(totalReward).div(100);
        donation = donation.mul(totalReward).div(100);
        _transferEther(commissionAccount, commission);
        _transferEther(donationAccount, donation);
        //Transfer remaining amount to Plotus contract
        _transferEther(address(pl), address(this).balance);
      }
      pl.callMarketResultEvent(commission, donation);    
    }

    function getReward(address _user)public view returns(uint){
      uint userPoints = userPredictionPoints[_user][currentPriceLocation];
      if(predictionStatus != PredictionStatus.ResultDeclared || userPoints == 0) {
        return 0;
      }
      (uint reward, ) = _calculateReward(userPoints);
      return reward;
    }

    function _calculateReward(uint userPoints) internal view returns(uint _reward, uint _postCappedRemaining) {
      _reward = 0;
      _postCappedRemaining = 0;
      (, , , , uint maxReturn, uint bonuReturnPerc) = marketConfig.getBasicMarketDetails();
       if(rewardToDistribute > 0) {
          _reward = userPoints.mul(rewardToDistribute).div(optionsAvailable[currentPriceLocation].predictionPoints);
          uint maxReturnCap = maxReturn * ethStaked[msg.sender][currentPriceLocation];
          if(_reward > maxReturnCap) {
            _postCappedRemaining = _reward.sub(maxReturnCap);
            _reward = maxReturnCap;
          }
        } else if(address(this).balance > 0){
          _reward = (ethStaked[msg.sender][currentPriceLocation].mul(bonuReturnPerc)).div(10000);
        }
    }

    function claimReward() public {
      require(!userClaimedReward[msg.sender],"Already claimed");
      require(predictionStatus == PredictionStatus.ResultDeclared,"Result not declared");
      userClaimedReward[msg.sender] = true;
      uint userPoints;
      userPoints = userPredictionPoints[msg.sender][currentPriceLocation];
      require(userPoints > 0,"must have atleast 0 points");
      (uint reward, uint postCappedRemaining) = _calculateReward(userPoints);
      if(postCappedRemaining > 0) {
        _transferEther(address(pl), postCappedRemaining);
      }
      _transferEther(msg.sender, ethStaked[msg.sender][currentPriceLocation].add(reward));
      pl.callClaimedEvent(msg.sender,reward, ethStaked[msg.sender][currentPriceLocation]);
    }

    function _transferEther(address payable _recipient, uint _amount) internal {
      _recipient.transfer(_amount);
    }

    function __callback(bytes32 myid, string memory result) public {
      // if(myid == closeMarketId) {
      //   _closeBet();
      // } else if(myid == marketResultId) {
        calculatePredictionResult(parseInt(result));
      // }
    }

}