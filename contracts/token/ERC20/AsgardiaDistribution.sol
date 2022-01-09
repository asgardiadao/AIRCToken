// SPDX-License-Identifier: UNLICENSED
/*
 .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.
| .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
| |      __      | || |    _______   | || |    ______    | || |      __      | || |  _______     | || |  ________    | || |     _____    | || |      __      | |
| |     /  \     | || |   /  ___  |  | || |  .' ___  |   | || |     /  \     | || | |_   __ \    | || | |_   ___ `.  | || |    |_   _|   | || |     /  \     | |
| |    / /\ \    | || |  |  (__ \_|  | || | / .'   \_|   | || |    / /\ \    | || |   | |__) |   | || |   | |   `. \ | || |      | |     | || |    / /\ \    | |
| |   / ____ \   | || |   '.___`-.   | || | | |    ____  | || |   / ____ \   | || |   |  __ /    | || |   | |    | | | || |      | |     | || |   / ____ \   | |
| | _/ /    \ \_ | || |  |`\____) |  | || | \ `.___]  _| | || | _/ /    \ \_ | || |  _| |  \ \_  | || |  _| |___.' / | || |     _| |_    | || | _/ /    \ \_ | |
| ||____|  |____|| || |  |_______.'  | || |  `._____.'   | || ||____|  |____|| || | |____| |___| | || | |________.'  | || |    |_____|   | || ||____|  |____|| |
| |              | || |              | || |              | || |              | || |              | || |              | || |              | || |              | |
| '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'

http://asgardiadao.io/
*/
pragma solidity ^0.8.0;

import "../../access/Ownable.sol";
import "./IERC20.sol";

/**
 * @title AsgardiaDistribution
 * @dev 5% of total supply of $AIRC will be awarded evenly to the top 100 IDO supporters.
 * Tokens will be distributed monthly linearly for 36 months.
 * $AIRC token will be listed on Pancake Swap.
 * 3% of $AIRC total supply is used for development and is vested linearly with a schedule of 3 years.
 * 3% of $AIRC total supply is used for marketing and is also vested linearly with a schedule of 3 years.
*/
contract AsgardiaDistribution is Ownable {

    /**
     * @dev AsgardiaToken $AIRC
     */
    IERC20 AIRCToken;
    // $AIRC Contract Address
    address tokenContract = 0x1F011BE04CaDA25E3fe07dE58D414dadA83733fF;

    uint256 public developmentFund = 428571000 ether;
    uint256 public marketFund = 428571000 ether;
    uint256 public candyFund = 714285000 ether;

    uint256 public startTime = 0;
    uint256 private oneMonth = 30 days;

    /**
     * @dev lock up fund data
     */
    struct LockFundRecord {
        uint256 total;
        uint256 unreleased;
        uint256 released;
        uint256 lastReleaseTime;
    }

    /**
     * @dev Throws if the firstRelease is not set
     */
    modifier MustEditStartTime(){
        require(startTime > 0,"release time is not set");
        _;
    }

    event ReleaseSuccess(uint256 amount);

    LockFundRecord[3] private lockFundRecordArr;

    /**
     * @dev Initialize the contract, setup lock up fund
     */
    constructor () {
        lockFundRecordArr[0] =  LockFundRecord({total:developmentFund,unreleased:developmentFund,released:0,lastReleaseTime:0});
        lockFundRecordArr[1] = LockFundRecord({total:marketFund,unreleased:marketFund,released:0,lastReleaseTime:0});
        lockFundRecordArr[2] = LockFundRecord({total:candyFund,unreleased:candyFund,released:0,lastReleaseTime:0});

        AIRCToken = IERC20(tokenContract);
    }

    /**
     * @dev Release fund, including development fund, market fund and candy fund
     */
    function releaseFund(uint256 fundType) public onlyOwner MustEditStartTime{

        require(fundType < 3,"invalid parameter");
        require(block.timestamp > startTime,"release time not reached");
        LockFundRecord storage lockFundRecord = lockFundRecordArr[fundType];

        require(lockFundRecord.unreleased > 0, "release completed");
        uint256 lastReleaseTime = lockFundRecord.lastReleaseTime;
        uint256 unReleaseMonth = 0;

        if (lastReleaseTime == 0){
            lastReleaseTime = startTime;
        }
        unReleaseMonth = (block.timestamp - lastReleaseTime) / oneMonth;

        if (unReleaseMonth > 0){
            uint256 monthOfAIRC = lockFundRecord.total / 36;
            uint256 releaseToken = monthOfAIRC * unReleaseMonth;
            if (releaseToken > 0 && releaseToken <= lockFundRecord.unreleased){
                AIRCToken.transfer(msg.sender, releaseToken);
                lockFundRecord.unreleased -= releaseToken;
                lockFundRecord.released += releaseToken;
                lockFundRecord.lastReleaseTime = block.timestamp;
                emit ReleaseSuccess(releaseToken);
            }
        }
    }

    /**
     * @dev Release information of the fund
     */
    function releaseInfo(uint256 fundType) view public returns(LockFundRecord memory){
        require(fundType < 3,"invalid parameter");
        return lockFundRecordArr[fundType];
    }

    /**
     * @dev Set start release time
     */
    function initStartTime(uint256 _startTime) public onlyOwner{
        require(_startTime == 0, "already set" );
        require(_startTime > block.timestamp, "must be greater than current time");
        startTime = _startTime;
    }

}