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

import "./IERC20.sol";

/**
 * @title AsgardiaCrowd
 * @dev After private and fundraising events, once we launch on PancakeSwap and other CEXs,
 * AsgardiaDAO will be open to the public. During the pre-sale phase, about 70% of the largest
 * supply (i.e. 9.9 billion Asgardia DAO) was sold, and the unsold AIRC was waiting to be destroyed.
 * The initial liquidity of AsgardiaDAO is 60% of all funds received in the pre-sale You can check our official
 * liquidity wallet.70% of the unfinished parts will be destroyed in the same proportion, and the remaining 30% of all
 * AIRC will be destroyed in the same proportion.
*/
contract AsgardiaCrowd {
    /**
     * @dev AsgardiaToken $AIRC
     */
    IERC20 AIRCToken;

    address private _owner;
    uint internal currentRound = 0;
    uint256 public totalCrowdfundingBNB = 0;
    uint256 private oneDay = 1 days;
    uint256 private threeDays = 3 days;
    uint256 private thirtyDays = 30 days;
    bool private bBurned = false;

    // $AIRC Contract Address
    address tokenContract = 0x8F766c4632ff8A746D4333755E1E60672f544B1b;

    event CrowdSuccess(address addr, uint256 amount);
    event ReleaseSuccess(address addr, uint256 amount);
    event BurnedSuccess(address, uint256 amount);

    /**
     * @dev fundraising data for each round
     */
    struct RoundData {
        uint roundIndex;
        uint256 totalCrowdfundingAIRC;
        uint256 totalCrowdfundingBNB;
        uint256 tokenPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 successfulCrowdfundingAIRC;
        uint256 successfulCrowdfundingBNB;
        uint256 numberOfCrowdfunding;
    }

    /**
     * @dev data on each donation
     */
    struct CrowdfundingRecord {
        uint256 tokenAmount;
        uint256 time;
    }

    /**
     * @dev data of each lock
     */
    struct CrowdfundingLockRecord {
        uint256 total;
        uint256 unreleased;
        uint256 released;
        uint256 lastReleaseTime;
    }
    mapping(uint256 => RoundData) internal roundsMap;
    mapping(address => CrowdfundingRecord[]) internal crowdfundingRecords;

    mapping(address => CrowdfundingLockRecord) internal releaseMap;
    mapping(address => CrowdfundingLockRecord) internal linearReleaseMap;

    /**
     * @dev Throws if the crowdfunding hasn't started.
     */
    modifier allowCrowdfundingCondition() {
        require(currentRound > 0, "the crowdfunding hasn't started yet");
        RoundData memory rounds = roundsMap[currentRound - 1];
        require(block.timestamp >= rounds.startTime && block.timestamp <= rounds.endTime, "The crowdfunding hasn't started yet or has already ended");
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Initialize the contract, setup owner and AIRC contract
     */
    constructor () {
        _owner = msg.sender;
        AIRCToken = IERC20(tokenContract);
    }

    /**
     * @dev withdraw assets to add liquidity and purchase land
     */
    function withdraw() public onlyOwner payable {
        payable(msg.sender).transfer(totalCrowdfundingBNB);
        totalCrowdfundingBNB = 0;
    }

    /**
     * @dev Transfer outstanding funds for destruction
     */
    function burn() public onlyOwner payable {
        require(currentRound >= 3, "the crowdfunding isn't over yet");
        require(bBurned == false, "has been burning");

        uint256 needBurnAmount = 0;
        for (uint i = 0; i < 3; i++){
            RoundData memory roundData = roundsMap[i];
            needBurnAmount += roundData.totalCrowdfundingAIRC - roundData.successfulCrowdfundingAIRC;
        }
        AIRCToken.transfer(msg.sender, needBurnAmount);
        bBurned = true;
        emit CrowdSuccess(msg.sender, needBurnAmount);
    }

    /**
     * @dev launched fundraising
     * 60% will be locked up for 3 days and released after the crowdfunding
     * 40% will be locked up for 30 days and released linearly every day after the crowdfunding
     * Emits a `CrowdSuccess` event.
     */
    function crowdfunding() public payable allowCrowdfundingCondition {
        RoundData storage roundData = roundsMap[currentRound - 1];
        require(msg.value + roundData.successfulCrowdfundingBNB <= roundData.totalCrowdfundingBNB, "The crowdfunding limit has been exceeded!");

        uint256 numberOfAIRC = msg.value / roundData.tokenPrice * 1 ether;

        CrowdfundingRecord[] storage _crowdfundingRecords = crowdfundingRecords[msg.sender];
        CrowdfundingLockRecord storage releaseRecord = releaseMap[msg.sender];
        CrowdfundingLockRecord storage linearReleaseRecord = linearReleaseMap[msg.sender];

        _crowdfundingRecords.push(CrowdfundingRecord({tokenAmount : numberOfAIRC, time : block.timestamp}));

        uint256 numberOf60Percent = numberOfAIRC * 3 / 5;
        uint256 numberOf40Percent = numberOfAIRC - numberOf60Percent;

        releaseRecord.unreleased += numberOf60Percent;
        releaseRecord.total += numberOf60Percent;

        linearReleaseRecord.unreleased += numberOf40Percent;
        linearReleaseRecord.total += numberOf40Percent;

        roundData.successfulCrowdfundingAIRC += numberOfAIRC;
        roundData.successfulCrowdfundingBNB += msg.value;

        if (_crowdfundingRecords.length == 1) {
            roundData.numberOfCrowdfunding += 1;
        }
        totalCrowdfundingBNB += msg.value;
        emit CrowdSuccess(msg.sender, numberOfAIRC);
    }

    /**
     * @dev get current round data
     */
    function currentRoundData() public allowCrowdfundingCondition view returns (RoundData memory) {
        return roundsMap[currentRound - 1];
    }

    function getRoundData(uint roundIndex) public allowCrowdfundingCondition view returns (RoundData memory){
        return roundsMap[roundIndex];
    }

    /**
     * @dev start the next round of sales, Returns a boolean value start the operation succeeded. owner only
     * Requirements:
     *
     * - `totalAIRC` $AIRC fundraising target total
     * - `totalBNB` $BNB fundraising target total
     * - `tokenPrice` $AIRC fundraising price
     * - `startTime` fundraising start time
     * - `endTime` fundraising end time
     */
    function startNextRounds(uint256 totalAIRC, uint256 totalBNB, uint256 tokenPrice, uint256 startTime, uint256 endTime) public onlyOwner returns (bool) {
        require(currentRound < 3, "the crowdfunding is over");
        if (currentRound > 0){
            require(roundsMap[currentRound - 1].endTime <= block.timestamp, "the crowdfunding hasn't started yet!");
        }
        currentRound += 1;
        roundsMap[currentRound - 1] = RoundData({
            roundIndex: currentRound,
            totalCrowdfundingAIRC: totalAIRC,
            totalCrowdfundingBNB: totalBNB,
            tokenPrice: tokenPrice,
            startTime: startTime,
            endTime: endTime,
            successfulCrowdfundingAIRC: 0,
            successfulCrowdfundingBNB : 0,
            numberOfCrowdfunding : 0
        });
        return true;
    }

    /**
     * @dev 3 days after the fundraising closes, 60% of the funds will be released
     */
    function release() public {
        require(currentRound >= 3, "the crowdfunding isn't over yet");
        require(block.timestamp >= roundsMap[2].endTime + threeDays, "release time not reached!");

        CrowdfundingLockRecord storage _releaseRecord = releaseMap[msg.sender];
        require(_releaseRecord.unreleased > 0, "release completed");

        uint256 releaseToken = _releaseRecord.unreleased;
        AIRCToken.transfer(msg.sender, releaseToken);
        _releaseRecord.unreleased = 0;
        _releaseRecord.released = releaseToken;
        _releaseRecord.lastReleaseTime = block.timestamp;
        emit ReleaseSuccess(msg.sender, releaseToken);
    }

    /**
     * @dev 30 days after the fundraising closes, 40% of the funds will be released
     */
    function linearRelease() public {
        require(currentRound >= 3, "the crowdfunding isn't over yet");
        require(block.timestamp >= roundsMap[2].endTime + thirtyDays, "release time not reached!");

        CrowdfundingLockRecord storage _releaseRecord = linearReleaseMap[msg.sender];
        require(_releaseRecord.unreleased > 0, "release completed");
        uint256 lastReleaseTime = _releaseRecord.lastReleaseTime;
        if (lastReleaseTime <= 0){
            lastReleaseTime = roundsMap[2].endTime + thirtyDays;
        }

        uint256 unReleaseDays = (block.timestamp - lastReleaseTime) / 1 days;
        if (unReleaseDays > 0){
            uint256 dayOfAIRC = _releaseRecord.total / 100;
            uint256 releaseToken = dayOfAIRC * unReleaseDays;
            if (releaseToken > 0 && releaseToken <= _releaseRecord.unreleased){
                AIRCToken.transfer(msg.sender, releaseToken);
                _releaseRecord.unreleased -= releaseToken;
                _releaseRecord.released += releaseToken;
                _releaseRecord.lastReleaseTime = block.timestamp;
                emit ReleaseSuccess(msg.sender, releaseToken);
            }
        }
    }

    /**
     * @dev get fundraising data, Returns a struct value of CrowdfundingRecord
     * - `addr` user address
     */
    function getRecords(address addr) public view returns (CrowdfundingRecord[] memory){
        return crowdfundingRecords[addr];
    }

    /**
     * @dev get release data, Returns a struct value of CrowdfundingLockRecord
     * - `addr` user address
     */
    function releaseInfo(address addr) public view returns (CrowdfundingLockRecord memory){
        return releaseMap[addr];
    }

    /**
     * @dev get linear release data, Returns a struct value of CrowdfundingLockRecord
     * - `addr` user address
     */
    function linearReleaseInfo(address addr) public view returns (CrowdfundingLockRecord memory){
        return linearReleaseMap[addr];
    }

    function releasableInfo(address addr) public view returns (uint256 availableAmount, uint256 unreleaseAmount){
        uint256 _availableAmount = 0;
        uint256 _unreleaseAmount = 0;
        CrowdfundingLockRecord memory releaseRecord = releaseMap[addr];
        if (block.timestamp >= roundsMap[2].endTime + threeDays){
            _availableAmount += releaseRecord.unreleased;
        }
        _unreleaseAmount += releaseRecord.unreleased;

        CrowdfundingLockRecord memory linearReleaseRecord = linearReleaseMap[addr];
        uint256 lastReleaseTime = linearReleaseRecord.lastReleaseTime;
        if (lastReleaseTime <= 0){
            lastReleaseTime = roundsMap[2].endTime + thirtyDays;
        }
        uint256 unReleaseDays = (block.timestamp - lastReleaseTime) / 1 days;
        if (unReleaseDays > 0){
            uint256 dayOfAIRC = linearReleaseRecord.total / 100;
            uint256 releaseToken = dayOfAIRC * unReleaseDays;
            if (releaseToken > 0 && releaseToken <= linearReleaseRecord.unreleased){
                _availableAmount += releaseToken;
            }
        }
        _unreleaseAmount += linearReleaseRecord.unreleased;
        return (_availableAmount, _unreleaseAmount);
    }
}