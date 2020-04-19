pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../abstract/EnvConstants.sol";
import "../abstract/BallotEnums.sol";
import "../GovChecker.sol";
import "../interface/IEnvStorage.sol";


contract BallotStorage is  GovChecker, EnvConstants, BallotEnums {
    using SafeMath for uint256;

    struct BallotBasic {
        //Ballot ID
        uint256 id;
        //시작 시간
        uint256 startTime;
        //종료 시간
        uint256 endTime;
        // 투표 종류
        uint256 ballotType;
        // 제안자
        address creator;
        // 투표 내용
        bytes memo;
        //총 투표자수
        uint256 totalVoters;
        // 진행상태
        uint256 powerOfAccepts;
        // 진행상태
        uint256 powerOfRejects;
        // 상태
        uint256 state;
        // 완료유무
        bool isFinalized;
        // 투표 기간
        uint256 duration;

    }

    //For MemberAdding/MemberRemoval/MemberSwap
    struct BallotMember {
        uint256 id;
        address oldMemberAddress;
        address newMemberAddress;
        bytes newNodeName; // name
        bytes newNodeId; // admin.nodeInfo.id is 512 bit public key
        bytes newNodeIp;
        uint256 newNodePort;
        uint256 lockAmount;
    }

    //For GovernanceChange
    struct BallotAddress {
        uint256 id;
        address newGovernanceAddress;
    }

    //For EnvValChange
    struct BallotVariable {
        //Ballot ID
        uint256 id;
        bytes32 envVariableName;
        uint256 envVariableType;
        bytes envVariableValue;
    }

    struct BallotPermissionGroup {
        uint256 id;
        uint256 gid;
        uint256 perm;
    }

    struct BallotPermissionAccount {
        uint256 id;
        address addr;
        uint256 gid;
    }

    struct BallotPermissionNode {
        uint256 id;
        bytes nid;
        uint256 perm;
    }

    struct Vote {
        uint256 voteId;
        uint256 ballotId;
        address voter;
        uint256 decision;
        uint256 power;
        uint256 time;
    }

    event BallotCreated(
        uint256 indexed ballotId,
        uint256 indexed ballotType,
        address indexed creator
    );

    event BallotStarted(
        uint256 indexed ballotId,
        uint256 indexed startTime,
        uint256 indexed endTime
    );

    event Voted(
        uint256 indexed voteid,
        uint256 indexed ballotId,
        address indexed voter,
        uint256 decision
    );

    event BallotFinalized(
        uint256 indexed ballotId,
        uint256 state
    );

    event BallotCanceled (
        uint256 indexed ballotId
    );

    event BallotUpdated (
        uint256 indexed ballotId,
        address indexed updatedBy
    );

    mapping(uint=>BallotBasic) internal ballotBasicMap;
    mapping(uint=>BallotMember) internal ballotMemberMap;
    mapping(uint=>BallotAddress) internal ballotAddressMap;
    mapping(uint=>BallotVariable) internal ballotVariableMap;

    mapping(uint=>BallotPermissionGroup) internal ballotPermissionGroupMap;
    mapping(uint=>BallotPermissionAccount) internal ballotPermissionAccountMap;
    mapping(uint=>BallotPermissionNode) internal ballotPermissionNodeMap;

    mapping(uint=>Vote) internal voteMap;
    mapping(uint=>mapping(address=>bool)) internal hasVotedMap;

    address internal previousBallotStorage;

    uint256 internal ballotCount = 0;

    constructor(address _registry) public {
        setRegistry(_registry);
    }

    modifier onlyValidTime(uint256 _startTime, uint256 _endTime) {
        require(_startTime > 0 && _endTime > 0, "start or end is 0");
        require(_endTime > _startTime, "start >= end"); // && _startTime > getTime()
        //uint256 diffTime = _endTime.sub(_startTime);
        // require(diffTime > minBallotDuration());
        // require(diffTime <= maxBallotDuration());
        _;
    }

    modifier onlyValidDuration(uint256 _duration){
        require(getMinVotingDuration() <= _duration, "Under min value of  duration");
        require(_duration <= getMaxVotingDuration(), "Over max value of duration");
        _;
    }

    modifier onlyGovOrCreator(uint256 _ballotId) {
        require((getGovAddress() == msg.sender) || (ballotBasicMap[_ballotId].creator == msg.sender), "No Permission");
        _;
    }

    modifier notDisabled() {
        require(address(this) == getBallotStorageAddress(), "Is Disabled");
        _;
    }

    function getMinVotingDuration() public view returns (uint256) {
        return IEnvStorage(getEnvStorageAddress()).getBallotDurationMin();
    }

    function getMaxVotingDuration() public view returns (uint256) {
        return IEnvStorage(getEnvStorageAddress()).getBallotDurationMax();
    }

    function getTime() public view returns (uint256) {
        return now;
    }

    function getPreviousBallotStorage() public view returns (address) {
        return previousBallotStorage;
    }

    function isDisabled() public view returns (bool) {
        return (address(this) != getBallotStorageAddress());
    }

    function getBallotCount() public view returns (uint256) {
        return ballotCount;
    }

    function getBallotBasic(uint256 _id) public view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 ballotType,
        address creator,
        bytes memo,
        uint256 totalVoters,
        uint256 powerOfAccepts,
        uint256 powerOfRejects,
        uint256 state,
        bool isFinalized,
        uint256 duration
    )
    {
        BallotBasic memory tBallot = ballotBasicMap[_id];
        startTime = tBallot.startTime;
        endTime = tBallot.endTime;
        ballotType = tBallot.ballotType;
        creator = tBallot.creator;
        memo = tBallot.memo;
        totalVoters = tBallot.totalVoters;
        powerOfAccepts = tBallot.powerOfAccepts;
        powerOfRejects = tBallot.powerOfRejects;
        state = tBallot.state;
        isFinalized = tBallot.isFinalized;
        duration = tBallot.duration;
    }

    function getBallotMember(uint256 _id) public view returns (
        address oldMemberAddress,
        address newMemberAddress,
        bytes newNodeName, // name
        bytes newNodeId, // admin.nodeInfo.id is 512 bit public key
        bytes newNodeIp,
        uint256 newNodePort,
        uint256 lockAmount
    )
    {
        BallotMember storage tBallot = ballotMemberMap[_id];
        oldMemberAddress = tBallot.oldMemberAddress;
        newMemberAddress = tBallot.newMemberAddress;
        newNodeName = tBallot.newNodeName;
        newNodeId = tBallot.newNodeId;
        newNodeIp = tBallot.newNodeIp;
        newNodePort = tBallot.newNodePort;
        lockAmount = tBallot.lockAmount;
    }

    function getBallotAddress(uint256 _id) public view returns (
        address newGovernanceAddress
    )
    {
        BallotAddress storage tBallot = ballotAddressMap[_id];
        newGovernanceAddress = tBallot.newGovernanceAddress;
    }

    function getBallotVariable(uint256 _id) public view returns (
        bytes32 envVariableName,
        uint256 envVariableType,
        bytes envVariableValue
    )
    {
        BallotVariable storage tBallot = ballotVariableMap[_id];
        envVariableName = tBallot.envVariableName;
        envVariableType = tBallot.envVariableType;
        envVariableValue = tBallot.envVariableValue;
    }

    function getBallotPermissionGroup(uint256 _id) public view returns (
        uint256 gid,
        uint256 perm
    )
    {
        BallotPermissionGroup storage g = ballotPermissionGroupMap[_id];
        gid = g.gid;
        perm = g.perm;
    }

    function getBallotPermissionAccount(uint256 _id) public view returns (
        address addr,
        uint256 gid
    )
    {
        BallotPermissionAccount storage a = ballotPermissionAccountMap[_id];
        addr = a.addr;
        gid = a.gid;
    }

    function getBallotPermissionNode(uint256 _id) public view returns (
        bytes nid,
        uint256 perm
    )
    {
        BallotPermissionNode storage n = ballotPermissionNodeMap[_id];
        nid = n.nid;
        perm = n.perm;
    }

    function setPreviousBallotStorage(address _address) public onlyOwner {
        require(_address != address(0), "Invalid address");
        previousBallotStorage = _address;
    }

    //For MemberAdding/MemberRemoval/MemberSwap
    function createBallotForMember(
        uint256 _id,
        uint256 _ballotType,
        address _creator,
        address _oldMemberAddress,
        address _newMemberAddress,
        bytes _newNodeName, // name
        bytes _newNodeId, // admin.nodeInfo.id is 512 bit public key
        bytes _newNodeIp,
        uint _newNodePort
    )
        public
        onlyGov
        notDisabled
    {
        require(
            _areMemberBallotParamValid(
                _ballotType,
                _oldMemberAddress,
                _newMemberAddress,
                _newNodeName,
                _newNodeId,
                _newNodeIp,
                _newNodePort
            ),
            "Invalid Parameter"
        );
        _createBallot(_id, _ballotType, _creator);
        BallotMember memory newBallot;
        newBallot.id = _id;
        newBallot.oldMemberAddress = _oldMemberAddress;
        newBallot.newMemberAddress = _newMemberAddress;
        newBallot.newNodeName = _newNodeName;
        newBallot.newNodeId = _newNodeId;
        newBallot.newNodeIp = _newNodeIp;
        newBallot.newNodePort = _newNodePort;
        ballotMemberMap[_id] = newBallot;

    }

    function createBallotForAddress(
        uint256 _id,
        uint256 _ballotType,
        address _creator,
        address _newGovernanceAddress
    )
        public
        onlyGov
        notDisabled
        returns (uint256)
    {
        require(_ballotType == uint256(BallotTypes.GovernanceChange), "Invalid Ballot Type");
        require(_newGovernanceAddress != address(0), "Invalid Parameter");

        _createBallot(_id, _ballotType, _creator);
        BallotAddress memory newBallot;
        newBallot.id = _id;
        newBallot.newGovernanceAddress = _newGovernanceAddress;
        ballotAddressMap[_id] = newBallot;
        return _id;
    }

    function createBallotForVariable(
        uint256 _id,
        uint256 _ballotType,
        address _creator,
        bytes32 _envVariableName,
        uint256 _envVariableType,
        bytes _envVariableValue
    )
        public
        onlyGov
        notDisabled
        returns (uint256)
    {
        require(
            _areVariableBallotParamValid(_ballotType, _envVariableName, _envVariableType, _envVariableValue),
            "Invalid Parameter"
        );
        _createBallot(_id, _ballotType, _creator);
        BallotVariable memory newBallot;
        newBallot.id = _id;
        newBallot.envVariableName = _envVariableName;
        newBallot.envVariableType = _envVariableType;
        newBallot.envVariableValue = _envVariableValue;
        ballotVariableMap[_id] = newBallot;
        return _id;
    }

    function createBallotForPermissionGroup(
        uint256 _id,
        uint256 _ballotType,
        address _creator,
        uint256 _gid,
        uint256 _perm
    )
        public onlyGov
        notDisabled
        returns (uint256)
    {
        require(_ballotType >= uint256(BallotTypes.PermissionGroupAdd) &&
                _ballotType <= uint256(BallotTypes.PermissionGroupRemove),
                "Invalid Ballot Type");
        if (_ballotType == uint256(BallotTypes.PermissionGroupAdd) ||
            _ballotType == uint256(BallotTypes.PermissionGroupChange)) {
            require(_perm == 0 || _perm == 1, "Invalid Permission");
        }

        _createBallot(_id, _ballotType, _creator);
        BallotPermissionGroup memory b;
        b.id = _id;
        b.gid = _gid;
        b.perm = _perm;
        ballotPermissionGroupMap[_id] = b;
        return _id;
    }

    function createBallotForPermissionAccount(
        uint256 _id,
        uint256 _ballotType,
        address _creator,
        address _addr,
        uint256 _gid
    )
        public onlyGov
        notDisabled
        returns (uint256)
    {
        require(_ballotType >= uint256(BallotTypes.PermissionAccountAdd) &&
                _ballotType <= uint256(BallotTypes.PermissionAccountRemove),
                "Invalid Ballot Type");
        if (_ballotType == uint256(BallotTypes.PermissionAccountAdd) ||
            _ballotType == uint256(BallotTypes.PermissionAccountChange)) {
            require(_addr != 0, "Invalid Permission");
        }

        _createBallot(_id, _ballotType, _creator);
        BallotPermissionAccount memory b;
        b.id = _id;
        b.addr = _addr;
        b.gid = _gid;
        ballotPermissionAccountMap[_id] = b;
        return _id;
    }

    function createBallotForPermissionNode(
        uint256 _id,
        uint256 _ballotType,
        address _creator,
        bytes _nid,
        uint256 _perm
    )
        public onlyGov
        notDisabled
        returns (uint256)
    {
        require(_ballotType >= uint256(BallotTypes.PermissionNodeAdd) &&
                _ballotType <= uint256(BallotTypes.PermissionNodeRemove),
                "Invalid Ballot Type");
        if (_ballotType == uint256(BallotTypes.PermissionNodeAdd) ||
            _ballotType == uint256(BallotTypes.PermissionNodeChange)) {
            require(_perm == 0 || _perm == 1, "Invalid Permission");
        }

        _createBallot(_id, _ballotType, _creator);
        BallotPermissionNode memory b;
        b.id = _id;
        b.nid = _nid;
        b.perm = _perm;
        ballotPermissionNodeMap[_id] = b;
        return _id;
    }

    function createVote(
        uint256 _voteId,
        uint256 _ballotId,
        address _voter,
        uint256 _decision,
        uint256 _power
    )
        public
        onlyGov
        notDisabled
        returns (uint256)
    {
        // Check decision type
        require((_decision == uint256(DecisionTypes.Accept))
            || (_decision == uint256(DecisionTypes.Reject)), "Invalid decision");
        // Check if ballot exists
        require(ballotBasicMap[_ballotId].id == _ballotId, "not existed Ballot");
        // Check if vote exists
        require(voteMap[_voteId].voteId != _voteId, "already existed voteId");
        // Check if voted
        require(!hasVotedMap[_ballotId][_voter], "already voted");
        require(ballotBasicMap[_ballotId].state
            == uint256(BallotStates.InProgress), "Not InProgress State");

        voteMap[_voteId] = Vote(_voteId, _ballotId, _voter, _decision, _power, getTime());
        _updateBallotForVote(_ballotId, _voter, _decision, _power);

        emit Voted(_voteId, _ballotId, _voter, _decision);
    }

    function startBallot(
        uint256 _ballotId,
        uint256 _startTime,
        uint256 _endTime
    )
        public
        onlyGov
        notDisabled
        onlyValidTime(_startTime, _endTime)
    {
        require(ballotBasicMap[_ballotId].id == _ballotId, "not existed Ballot");
        require(ballotBasicMap[_ballotId].isFinalized == false, "already finalized");
        require(ballotBasicMap[_ballotId].state == uint256(BallotStates.Ready), "Not Ready State");

        BallotBasic storage _ballot = ballotBasicMap[_ballotId];
        _ballot.startTime = _startTime;
        _ballot.endTime = _endTime;
        _ballot.state = uint256(BallotStates.InProgress);
        emit BallotStarted(_ballotId, _startTime, _endTime);
    }

    function updateBallotMemo(
        uint256 _ballotId,
        bytes _memo
    )
        public
        onlyGovOrCreator(_ballotId)
        notDisabled
    {
        require(ballotBasicMap[_ballotId].id == _ballotId, "not existed Ballot");
        require(ballotBasicMap[_ballotId].isFinalized == false, "already finalized");
        BallotBasic storage _ballot = ballotBasicMap[_ballotId];
        _ballot.memo = _memo;
        emit BallotUpdated (_ballotId, msg.sender);
    }

    function updateBallotDuration(
        uint256 _ballotId,
        uint256 _duration
    )
        public
        onlyGovOrCreator(_ballotId)
        notDisabled
        onlyValidDuration(_duration)
    {
        require(ballotBasicMap[_ballotId].id == _ballotId, "not existed Ballot");
        require(ballotBasicMap[_ballotId].isFinalized == false, "already finalized");
        require(ballotBasicMap[_ballotId].state == uint256(BallotStates.Ready), "Not Ready State");

        BallotBasic storage _ballot = ballotBasicMap[_ballotId];
        _ballot.duration = _duration;
        emit BallotUpdated (_ballotId, msg.sender);
    }

    function updateBallotMemberLockAmount(
        uint256 _ballotId,
        uint256 _lockAmount
    )
        public
        onlyGov
        notDisabled
    {
        require(ballotBasicMap[_ballotId].id == _ballotId, "not existed Ballot");
        require(ballotMemberMap[_ballotId].id == _ballotId, "not existed BallotMember");
        require(ballotBasicMap[_ballotId].isFinalized == false, "already finalized");
        require(ballotBasicMap[_ballotId].state == uint256(BallotStates.Ready), "Not Ready State");
        BallotMember storage _ballot = ballotMemberMap[_ballotId];
        _ballot.lockAmount = _lockAmount;
        emit BallotUpdated (_ballotId, msg.sender);
    }

    // cancel ballot info
    function cancelBallot(uint256 _ballotId) public onlyGovOrCreator(_ballotId) notDisabled {
        require(ballotBasicMap[_ballotId].id == _ballotId, "not existed Ballot");
        require(ballotBasicMap[_ballotId].isFinalized == false, "already finalized");

        require(ballotBasicMap[_ballotId].state == uint256(BallotStates.Ready), "Not Ready State");
        BallotBasic storage _ballot = ballotBasicMap[_ballotId];
        _ballot.state = uint256(BallotStates.Canceled);
        emit BallotCanceled (_ballotId);
    }

    // finalize ballot info
    function finalizeBallot(uint256 _ballotId, uint256 _ballotState) public onlyGov notDisabled {
        require(ballotBasicMap[_ballotId].id == _ballotId, "not existed Ballot");
        require(ballotBasicMap[_ballotId].isFinalized == false, "already finalized");
        require((_ballotState == uint256(BallotStates.Accepted))
            || (_ballotState == uint256(BallotStates.Rejected)), "Invalid Ballot State");

        BallotBasic storage _ballot = ballotBasicMap[_ballotId];
        _ballot.state = _ballotState;
        _ballot.isFinalized = true;
        emit BallotFinalized (_ballotId, _ballotState);
    }

    function hasAlreadyVoted(uint56 _ballotId, address _voter) public view returns (bool) {
        return hasVotedMap[_ballotId][_voter];
    }

    function getVote(uint256 _voteId) public view returns (
        uint256 voteId,
        uint256 ballotId,
        address voter,
        uint256 decision,
        uint256 power,
        uint256 time
    )
    {
        require(voteMap[_voteId].voteId == _voteId, "not existed voteId");
        Vote memory _vote = voteMap[_voteId];
        voteId = _vote.voteId;
        ballotId = _vote.ballotId;
        voter = _vote.voter;
        decision = _vote.decision;
        power = _vote.power;
        time = _vote.time;
    }

    function getBallotPeriod(uint256 _id) public view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 duration
    )
    {
        BallotBasic memory tBallot = ballotBasicMap[_id];
        startTime = tBallot.startTime;
        endTime = tBallot.endTime;
        duration = tBallot.duration;
    }

    function getBallotVotingInfo(uint256 _id) public view returns (
        uint256 totalVoters,
        uint256 powerOfAccepts,
        uint256 powerOfRejects

    )
    {
        BallotBasic memory tBallot = ballotBasicMap[_id];
        totalVoters = tBallot.totalVoters;
        powerOfAccepts = tBallot.powerOfAccepts;
        powerOfRejects = tBallot.powerOfRejects;
    }

    function getBallotState(uint256 _id) public view returns (
        uint256 ballotType,
        uint256 state,
        bool isFinalized
    )
    {
        BallotBasic memory tBallot = ballotBasicMap[_id];
        ballotType = tBallot.ballotType;
        state = tBallot.state;
        isFinalized = tBallot.isFinalized;
    }

    function _createBallot(
        uint256 _id,
        uint256 _ballotType,
        address _creator
    )
        internal
    {
        require(ballotBasicMap[_id].id != _id, "Already existed ballot");

        BallotBasic memory newBallot;
        newBallot.id = _id;
        newBallot.ballotType = _ballotType;
        newBallot.creator = _creator;
//        newBallot.memo = _memo;
        newBallot.state = uint256(BallotStates.Ready);
        newBallot.isFinalized = false;
//        newBallot.duration = _duration;
        ballotBasicMap[_id] = newBallot;
        ballotCount = ballotCount.add(1);
        emit BallotCreated(_id, _ballotType, _creator);
    }

    function _areMemberBallotParamValid(
        uint256 _ballotType,
        address _oldMemberAddress,
        address _newMemberAddress,
        bytes _newName,
        bytes _newNodeId, // admin.nodeInfo.id is 512 bit public key
        bytes _newNodeIp,
        uint _newNodePort
    )
        internal
        pure
        returns (bool)
    {
        require((_ballotType >= uint256(BallotTypes.MemberAdd))
            && (_ballotType <= uint256(BallotTypes.MemberChange)), "Invalid Ballot Type");

        if (_ballotType == uint256(BallotTypes.MemberRemoval)){
            require(_oldMemberAddress != address(0), "Invalid old member address");
            require(_newMemberAddress == address(0), "Invalid new member address");
            require(_newName.length == 0, "Invalid new node name");
            require(_newNodeId.length == 0, "Invalid new node id");
            require(_newNodeIp.length == 0, "Invalid new node IP");
            require(_newNodePort == 0, "Invalid new node Port");
        }else {
            require(_newName.length > 0, "Invalid new node name");
            require(_newNodeId.length == 64, "Invalid new node id");
            require(_newNodeIp.length > 0, "Invalid new node IP");
            require(_newNodePort > 0, "Invalid new node Port");
            if (_ballotType == uint256(BallotTypes.MemberAdd)) {
                require(_oldMemberAddress == address(0), "Invalid old member address");
                require(_newMemberAddress != address(0), "Invalid new member address");
            } else if (_ballotType == uint256(BallotTypes.MemberChange)) {
                require(_oldMemberAddress != address(0), "Invalid old member address");
                require(_newMemberAddress != address(0), "Invalid new member address");
            }
        }

        return true;
    }

    function _areVariableBallotParamValid(
        uint256 _ballotType,
        bytes32 _envVariableName,
        uint256 _envVariableType,
        bytes _envVariableValue
    )
        internal
        pure
        returns (bool)
    {
        require(_ballotType == uint256(BallotTypes.EnvValChange), "Invalid Ballot Type");
        require(_envVariableName > 0, "Invalid environment variable name");
        require(_envVariableType >= uint256(VariableTypes.Int), "Invalid environment variable Type");
        require(_envVariableType <= uint256(VariableTypes.String), "Invalid environment variable Type");
        require(_envVariableValue.length > 0, "Invalid environment variable value");

        return true;
    }

    // update ballot
    function _updateBallotForVote(
        uint256 _ballotId,
        address _voter,
        uint256 _decision,
        uint256 _power
    )
        internal
    {
        // c1. actionType 범위
        require((_decision == uint256(DecisionTypes.Accept))
            || (_decision == uint256(DecisionTypes.Reject)), "Invalid decision");
        // c2. ballotId 존재 하는지 확인
        require(ballotBasicMap[_ballotId].id == _ballotId, "not existed Ballot");
        // c3. 이미 vote 했는지 확인
        require(hasVotedMap[_ballotId][_voter] == false, "already voted");

        //1.get ballotBasic
        BallotBasic storage _ballot = ballotBasicMap[_ballotId];
        //2. 투표 여부 등록
        hasVotedMap[_ballotId][_voter] = true;
        //3. update totalVoters
        _ballot.totalVoters = _ballot.totalVoters.add(1);
        //4. Update power of accept/reject
        if (_decision == uint256(DecisionTypes.Accept)){
            _ballot.powerOfAccepts = _ballot.powerOfAccepts.add(_power);
        } else {
            _ballot.powerOfRejects = _ballot.powerOfRejects.add(_power);
        }
    }
}
