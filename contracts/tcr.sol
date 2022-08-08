// Most of the code in this contract is derived from the generic TCR implementation from Mike Goldin and (the adChain) team
// This contract strips out most of the details and only keeps the basic TCR functionality (apply/propose, challenge, vote, resolve)
// Consider this to be the "hello world" for TCR implementation
// For real world usage, please refer to the generic TCR implementation
// https://github.com/skmgoldin/tcr

pragma solidity ^0.8.15;
pragma experimental ABIEncoderV2;

// import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./token.sol";

// import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Tcr {
    // using SafeMath for uint256;

    struct Listing {
        uint256 applicationExpiry; // Expiration date of apply stage
        bool whitelisted; // Indicates registry status
        address owner; // Owner of Listing
        uint256 deposit; // Number of tokens in the listing
        uint256 challengeId; // the challenge id of the current challenge
        string data; // name of listing (for UI)
        uint256 arrIndex; // arrayIndex of listing in listingNames array (for deletion)
    }

    // instead of using the elegant PLCR voting, we are using just a list because this is *simple-TCR*
    struct Vote {
        bool value;
        uint256 stake;
        bool claimed;
    }

    struct Poll {
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 commitEndDate;
        bool passed;
        mapping(address => Vote) votes; // revealed by default; no partial locking
    }

    struct Challenge {
        address challenger; // Owner of Challenge
        bool resolved; // Indication of if challenge is resolved
        uint256 stake; // Number of tokens at stake for either party during challenge
        uint256 rewardPool; // number of tokens from losing side - winning reward
        uint256 totalTokens; // number of tokens from winning side - to be returned
    }

    // Maps challengeIDs to associated challenge data
    mapping(uint256 => Challenge) private challenges;

    // Maps listingHashes to associated listingHash data
    mapping(bytes32 => Listing) private listings;
    string[] public listingNames;

    // Maps polls to associated challenge
    mapping(uint256 => Poll) private polls;

    // Global Variables
    StandardToken public token;
    string public name;
    uint256 public minDeposit;
    uint256 public applyStageLen;
    uint256 public commitStageLen;
    string public description;
    uint256 private constant INITIAL_POLL_NONCE = 0;
    uint256 public pollNonce;

    // Events
    event _Application(
        bytes32 indexed listingHash,
        uint256 deposit,
        string data,
        address indexed applicant
    );
    event _Challenge(
        bytes32 indexed listingHash,
        uint256 challengeId,
        address indexed challenger
    );
    event _Vote(
        bytes32 indexed listingHash,
        uint256 challengeId,
        address indexed voter
    );
    event _ResolveChallenge(
        bytes32 indexed listingHash,
        uint256 challengeId,
        address indexed resolver
    );
    event _UpdateStatus(
        bytes32 indexed listingHash,
        address indexed updater
    );
    event _RewardClaimed(
        uint256 indexed challengeId,
        uint256 reward,
        address indexed voter
    );

    // using the constructor to initialize the TCR parameters
    // again, to keep it simple, skipping the Parameterizer and ParameterizerFactory
    constructor(
        string memory _name,
        string memory _description,
        address _token,
        uint256[] memory _parameters
    ) {
        require(_token != address(0), "Token address should not be 0 address.");

        token = StandardToken(_token);
        name = _name;

        // minimum deposit for listing to be whitelisted
        minDeposit = _parameters[0];

        // period over which applicants wait to be whitelisted
        applyStageLen = _parameters[1];

        // length of commit period for voting
        commitStageLen = _parameters[2];

        description = _description;
        
        // Initialize the poll nonce
        pollNonce = INITIAL_POLL_NONCE;
    }

    function getChallenge(uint256 _challengeId) public view returns (Challenge memory){
        return challenges[_challengeId];
    }
    function getPoll(uint256 _challengeId) public view returns (uint256 votesFor,uint256 votesAgainst,uint256 commitEndDate,bool passed){
        return (
            polls[_challengeId].votesFor,
            polls[_challengeId].votesAgainst,
            polls[_challengeId].commitEndDate,
            polls[_challengeId].passed
            );
    }

    // returns whether a listing is already whitelisted
    function isWhitelisted(bytes32 _listingHash)
        public
        view
        returns (bool whitelisted)
    {
        return listings[_listingHash].whitelisted;
    }

    // returns if a listing is in apply stage
    function appWasMade(bytes32 _listingHash)
        public
        view
        returns (bool exists)
    {
        return listings[_listingHash].applicationExpiry > 0;
    }

    // get all listing names (for UI)
    // not to be used in a production use case
    function getAllListings() public view returns (string[] memory) {
        string[] memory listingArr = new string[](listingNames.length);
        for (uint256 i = 0; i < listingNames.length; i++) {
            listingArr[i] = listingNames[i];
        }
        return listingArr;
    }

    // get details of this registry (for UI)
    function getDetails()
        public
        view
        returns (
            string memory,
            address,
            uint256,
            uint256,
            uint256,
            string memory,
            uint256
        )
    {
        string memory _name = name;
        return (
            _name,
            address(token),
            minDeposit,
            applyStageLen,
            commitStageLen,
            description,
            pollNonce
        );
    }

    // get details of a listing (for UI)
    function getListingDetails(bytes32 _listingHash)
        public
        view
        returns (
            bool,
            address,
            uint256,
            uint256,
            uint256,
            string memory
        )
    {
        Listing memory listingIns = listings[_listingHash];

        // Listing must be in apply stage or already on the whitelist
        require(
            appWasMade(_listingHash) || listingIns.whitelisted,
            "Listing does not exist."
        );

        return (
            listingIns.whitelisted, //0
            listingIns.owner, // 1
            listingIns.deposit, // 2
            listingIns.challengeId, //3
            listingIns.applicationExpiry, //4
            listingIns.data //5
        );
    }

    // proposes a listing to be whitelisted
    function propose(
        bytes32 _listingHash,
        uint256 _amount,
        string calldata _data
    ) external {
        require(
            !isWhitelisted(_listingHash),
            "Listing is already whitelisted."
        );
        require(
            !appWasMade(_listingHash),
            "Listing is already in apply stage."
        );
        require(_amount >= minDeposit, "Not enough stake for application.");

        // Sets owner
        Listing storage listing = listings[_listingHash];
        listing.owner = msg.sender;
        listing.data = _data;
        listingNames.push(listing.data);
        listing.arrIndex = listingNames.length - 1;

        // Sets apply stage end time
        // now or block.timestamp is safe here (can live with ~15 sec approximation)
        /* solium-disable-next-line security/no-block-members */
        listing.applicationExpiry = block.timestamp + applyStageLen; // equivalent to now.add ???
        listing.deposit = _amount;

        // Transfer tokens from user
        require(
            token.transferFrom(listing.owner, address(this), _amount),
            "Token transfer failed."
        );

        emit _Application(_listingHash, _amount, _data, msg.sender);
    }

    // challenges a listing from being whitelisted
    function challenge(bytes32 _listingHash, uint256 _amount)
        external
        returns (uint256 challengeId)
    {
        Listing storage listing = listings[_listingHash];

        // Listing must be in apply stage or already on the whitelist
        require(
            appWasMade(_listingHash) || listing.whitelisted,
            "Listing does not exist."
        );

        // Prevent multiple challenges
        require(
            listing.challengeId == 0 ||
                challenges[listing.challengeId].resolved,
            "Listing is already challenged."
        );

        // check if apply stage is active
        /* solium-disable-next-line security/no-block-members */
        require(
            listing.applicationExpiry > block.timestamp,
            "Apply stage has passed."
        );

        // check if enough amount is staked for challenge
        require(
            _amount >= listing.deposit,
            "Not enough stake passed for challenge."
        );

        pollNonce = pollNonce + 1;
        challenges[pollNonce] = Challenge({
            challenger: msg.sender,
            stake: _amount,
            resolved: false,
            totalTokens: 0,
            rewardPool: 0
        });

        // create a new poll for the challenge
        // polls[pollNonce] = Poll({
        //     votesFor: 0,
        //     votesAgainst: 0,
        //     passed: false,
        //     commitEndDate: block.timestamp + commitStageLen /* solium-disable-line security/no-block-members */
        // });
        polls[pollNonce].votesFor = 0;
        polls[pollNonce].votesAgainst = 0;
        polls[pollNonce].passed = false;
        polls[pollNonce].commitEndDate = block.timestamp + commitStageLen;

        // Updates listingHash to store most recent challenge
        listing.challengeId = pollNonce;

        // Transfer tokens from challenger
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed."
        );

        emit _Challenge(_listingHash, pollNonce, msg.sender);
        return pollNonce;
    }

    // commits a vote for/against a listing
    // plcr voting is not being used here
    // to keep it simple, we just store the choice as a bool - true is for and false is against
    function vote(
        bytes32 _listingHash,
        uint256 _amount,
        bool _choice
    ) public {
        Listing storage listing = listings[_listingHash];

        // Listing must be in apply stage or already on the whitelist
        require(
            appWasMade(_listingHash) || listing.whitelisted,
            "Listing does not exist."
        );

        // Check if listing is challenged
        require(
            listing.challengeId > 0 &&
                !challenges[listing.challengeId].resolved,
            "Listing is not challenged."
        );

        Poll storage poll = polls[listing.challengeId];

        // check if commit stage is active
        /* solium-disable-next-line security/no-block-members */
        require(
            poll.commitEndDate > block.timestamp,
            "Commit period has passed."
        );

        // Transfer tokens from voter
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed."
        );

        if (_choice) {
            poll.votesFor += _amount;
        } else {
            poll.votesAgainst += _amount;
        }

        // TODO: fix vote override when same person is voing again
        poll.votes[msg.sender] = Vote({
            value: _choice,
            stake: _amount,
            claimed: false
        });

        emit _Vote(_listingHash, listing.challengeId, msg.sender);
    }

    // check if the listing can be whitelisted
    function canBeWhitelisted(bytes32 _listingHash) public view returns (bool) {
        uint256 challengeId = listings[_listingHash].challengeId;

        // Ensures that the application was made,
        // the application period has ended,
        // the listingHash can be whitelisted,
        // and either: the challengeId == 0, or the challenge has been resolved.
        /* solium-disable */
        if (
            appWasMade(_listingHash) &&
            listings[_listingHash].applicationExpiry < block.timestamp &&
            !isWhitelisted(_listingHash) &&
            (challengeId == 0 || challenges[challengeId].resolved == true)
        ) {
            return true;
        }

        return false;
    }

    // updates the status of a listing
    function updateStatus(bytes32 _listingHash) public {
        if (canBeWhitelisted(_listingHash)) {
            listings[_listingHash].whitelisted = true;
            emit _UpdateStatus(_listingHash, msg.sender);
        } else {
            resolveChallenge(_listingHash);
        }
    }

    // ends a poll and returns if the poll passed or not
    function endPoll(uint256 challengeId) private returns (bool didPass) {
        require(polls[challengeId].commitEndDate > 0, "Poll does not exist.");
        Poll storage poll = polls[challengeId];

        // check if commit stage is active
        /* solium-disable-next-line security/no-block-members */
        require(
            poll.commitEndDate < block.timestamp,
            "Commit period is active."
        );

        if (poll.votesFor >= poll.votesAgainst) {
            poll.passed = true;
        } else {
            poll.passed = false;
        }

        return poll.passed;
    }

    // resolves a challenge and calculates rewards
    function resolveChallenge(bytes32 _listingHash) private {
        // Check if listing is challenged
        Listing memory listing = listings[_listingHash];
        require(
            listing.challengeId > 0 &&
                !challenges[listing.challengeId].resolved,
            "Listing is not challenged."
        );

        uint256 challengeId = listing.challengeId;

        // end the poll
        bool pollPassed = endPoll(challengeId);

        // updated challenge status
        challenges[challengeId].resolved = true;

        address challenger = challenges[challengeId].challenger;

        // Case: challenge failed
        if (pollPassed) {
            challenges[challengeId].totalTokens = polls[challengeId].votesFor;
            challenges[challengeId].rewardPool =
                challenges[challengeId].stake +
                polls[challengeId].votesAgainst;
            listings[_listingHash].whitelisted = true;
        } else {
            // Case: challenge succeeded
            // give back the challenge stake to the challenger
            require(
                token.transfer(challenger, challenges[challengeId].stake),
                "Challenge stake return failed."
            );
            challenges[challengeId].totalTokens = polls[challengeId]
                .votesAgainst;
            challenges[challengeId].rewardPool =
                listing.deposit +
                polls[challengeId].votesFor;
            delete listings[_listingHash];
            delete listingNames[listing.arrIndex];
        }

        emit _ResolveChallenge(_listingHash, challengeId, msg.sender);
    }
    function canClaim(uint256 _challengeId) public view returns (bool){
        // check if challenge is resolved
        if(challenges[_challengeId].resolved == false){
            return false;
        }

        Poll storage poll = polls[_challengeId];
        Vote storage voteInstance = poll.votes[msg.sender];

        // check if vote reward is already claimed
        if(voteInstance.claimed == true){
            return false;
        }
        // check if winning party
        if ((poll.passed && !voteInstance.value) ||
            (!poll.passed && voteInstance.value)) {
            return false;
        }
        return true;
    }
    // claim rewards for a vote
    function claimRewards(uint256 challengeId) public {
        // check if challenge is resolved
        require(
            challenges[challengeId].resolved == true,
            "Challenge is not resolved."
        );

        Poll storage poll = polls[challengeId];
        Vote storage voteInstance = poll.votes[msg.sender];

        // check if vote reward is already claimed
        require(
            voteInstance.claimed == false,
            "Vote reward is already claimed."
        );

        // if winning party, calculate reward and transfer
        if (
            (poll.passed && voteInstance.value) ||
            (!poll.passed && !voteInstance.value)
        ) {
            // uint256 reward = (
            //     challenges[challengeId].rewardPool.div(
            //         challenges[challengeId].totalTokens
            //     )
            // ).mul(voteInstance.stake);
            uint256 reward = (challenges[challengeId].rewardPool / challenges[challengeId].totalTokens) * voteInstance.stake;
            uint256 total = voteInstance.stake + reward;
            require(
                token.transfer(msg.sender, total),
                "Voting reward transfer failed."
            );
            emit _RewardClaimed(challengeId, total, msg.sender);
        }

        voteInstance.claimed = true;
    }
}
