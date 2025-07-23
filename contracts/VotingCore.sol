// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Pollify - Decentralized Polling System
 * @dev A smart contract for creating and managing decentralized polls
 * @author Your Name
 */
contract Polls {
    struct VotingOptions {
        string description;
        uint256 voteCount;
    }

    struct PollInfo {
        string title;
        address creator;
        bool isActive;
        uint256 createdAt;
        uint256 totalVotes;
        VotingOptions[] options;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterChoice;
    }
    
    mapping(uint256 => PollInfo) private polls;
    mapping(address => uint256[]) private userPolls;
    uint256 private pollCounter;
    
    // Events with indexed parameters for better filtering
    event PollCreated(
        uint256 indexed pollId, 
        string title, 
        address indexed creator,
        uint256 timestamp
    );
    
    event VoteRegistered(
        uint256 indexed pollId, 
        uint256 indexed optionIndex, 
        address indexed voter,
        uint256 timestamp
    );
    
    event PollFinished(
        uint256 indexed pollId, 
        address indexed creator,
        uint256 timestamp
    );

    // Custom errors (gas efficient)
    error InvalidOptionsCount();
    error EmptyTitle();
    error EmptyOption();
    error PollNotFound();
    error PollInactive();
    error AlreadyVoted();
    error InvalidOption();
    error NotPollCreator();
    error PollAlreadyFinished();

    /**
     * @dev Creates a new poll
     * @param _title The title of the poll
     * @param _options Array of voting options (2-6 options allowed)
     */
    function createPoll(string memory _title, string[] memory _options) 
        external 
        returns (uint256) 
    {
        if (_options.length < 2 || _options.length > 6) {
            revert InvalidOptionsCount();
        }
        if (bytes(_title).length == 0) {
            revert EmptyTitle();
        }

        pollCounter++;
        PollInfo storage newPoll = polls[pollCounter];
        newPoll.title = _title;
        newPoll.creator = msg.sender;
        newPoll.isActive = true;
        newPoll.createdAt = block.timestamp;

        for (uint256 i = 0; i < _options.length; i++) {
            if (bytes(_options[i]).length == 0) {
                revert EmptyOption();
            }
            newPoll.options.push(VotingOptions({
                description: _options[i], 
                voteCount: 0
            }));
        }

        userPolls[msg.sender].push(pollCounter);
        
        emit PollCreated(pollCounter, _title, msg.sender, block.timestamp);
        return pollCounter;
    }

    /**
     * @dev Vote on a specific poll option
     * @param _pollId The ID of the poll
     * @param _optionIndex The index of the chosen option
     */
    function vote(uint256 _pollId, uint256 _optionIndex) external {
        if (_pollId == 0 || _pollId > pollCounter) {
            revert PollNotFound();
        }
        
        PollInfo storage poll = polls[_pollId];
        
        if (!poll.isActive) {
            revert PollInactive();
        }
        if (poll.hasVoted[msg.sender]) {
            revert AlreadyVoted();
        }
        if (_optionIndex >= poll.options.length) {
            revert InvalidOption();
        }

        poll.options[_optionIndex].voteCount++;
        poll.totalVotes++;
        poll.hasVoted[msg.sender] = true;
        poll.voterChoice[msg.sender] = _optionIndex;

        emit VoteRegistered(_pollId, _optionIndex, msg.sender, block.timestamp);
    }

    /**
     * @dev Finish a poll (only creator can call this)
     * @param _pollId The ID of the poll to finish
     */
    function finishPoll(uint256 _pollId) external {
        if (_pollId == 0 || _pollId > pollCounter) {
            revert PollNotFound();
        }
        
        PollInfo storage poll = polls[_pollId];
        
        if (poll.creator != msg.sender) {
            revert NotPollCreator();
        }
        if (!poll.isActive) {
            revert PollAlreadyFinished();
        }

        poll.isActive = false;
        emit PollFinished(_pollId, msg.sender, block.timestamp);
    }

    // View functions
    
    /**
     * @dev Get basic poll information
     * @param _pollId The ID of the poll
     * @return title The poll title
     * @return creator The poll creator address
     * @return isActive Whether the poll is active
     * @return optionsCount Number of voting options
     * @return totalVotes Total number of votes cast
     * @return createdAt Timestamp when poll was created
     */
    function getPollInfo(uint256 _pollId) 
        external 
        view 
        returns (
            string memory title,
            address creator,
            bool isActive,
            uint256 optionsCount,
            uint256 totalVotes,
            uint256 createdAt
        ) 
    {
        if (_pollId == 0 || _pollId > pollCounter) {
            revert PollNotFound();
        }
        
        PollInfo storage poll = polls[_pollId];
        return (
            poll.title, 
            poll.creator, 
            poll.isActive, 
            poll.options.length,
            poll.totalVotes,
            poll.createdAt
        );
    }

    /**
     * @dev Get specific poll option details
     * @param _pollId The ID of the poll
     * @param _optionIndex The index of the option
     * @return description The option description
     * @return voteCount Number of votes for this option
     */
    function getPollOption(uint256 _pollId, uint256 _optionIndex) 
        external 
        view 
        returns (string memory description, uint256 voteCount) 
    {
        if (_pollId == 0 || _pollId > pollCounter) {
            revert PollNotFound();
        }
        
        PollInfo storage poll = polls[_pollId];
        if (_optionIndex >= poll.options.length) {
            revert InvalidOption();
        }
        
        VotingOptions storage option = poll.options[_optionIndex];
        return (option.description, option.voteCount);
    }

    /**
     * @dev Get all options for a poll
     * @param _pollId The ID of the poll
     * @return descriptions Array of option descriptions
     * @return voteCounts Array of vote counts for each option
     */
    function getAllPollOptions(uint256 _pollId) 
        external 
        view 
        returns (string[] memory descriptions, uint256[] memory voteCounts) 
    {
        if (_pollId == 0 || _pollId > pollCounter) {
            revert PollNotFound();
        }
        
        PollInfo storage poll = polls[_pollId];
        uint256 optionsLength = poll.options.length;
        
        descriptions = new string[](optionsLength);
        voteCounts = new uint256[](optionsLength);
        
        for (uint256 i = 0; i < optionsLength; i++) {
            descriptions[i] = poll.options[i].description;
            voteCounts[i] = poll.options[i].voteCount;
        }
        
        return (descriptions, voteCounts);
    }

    /**
     * @dev Check if an address has voted on a specific poll
     * @param _pollId The ID of the poll
     * @param _voter The address to check
     * @return Whether the address has voted
     */
    function hasUserVoted(uint256 _pollId, address _voter) 
        external 
        view 
        returns (bool) 
    {
        if (_pollId == 0 || _pollId > pollCounter) {
            revert PollNotFound();
        }
        return polls[_pollId].hasVoted[_voter];
    }

    /**
     * @dev Get the choice made by a voter
     * @param _pollId The ID of the poll
     * @param _voter The address of the voter
     * @return The option index chosen by the voter
     */
    function getVoterChoice(uint256 _pollId, address _voter) 
        external 
        view 
        returns (uint256) 
    {
        if (_pollId == 0 || _pollId > pollCounter) {
            revert PollNotFound();
        }
        if (!polls[_pollId].hasVoted[_voter]) {
            revert("User has not voted");
        }
        return polls[_pollId].voterChoice[_voter];
    }

    /**
     * @dev Get polls created by a specific user
     * @param _creator The address of the creator
     * @return Array of poll IDs created by the user
     */
    function getUserPolls(address _creator) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userPolls[_creator];
    }

    /**
     * @dev Get the total number of polls created
     * @return The total poll count
     */
    function getTotalPolls() external view returns (uint256) {
        return pollCounter;
    }

    /**
     * @dev Get poll results with percentages
     * @param _pollId The ID of the poll  
     * @return descriptions Array of option descriptions
     * @return voteCounts Array of vote counts
     * @return percentages Array of vote percentages (scaled by 100)
     */
    function getPollResults(uint256 _pollId) 
        external 
        view 
        returns (
            string[] memory descriptions, 
            uint256[] memory voteCounts,
            uint256[] memory percentages
        ) 
    {
        if (_pollId == 0 || _pollId > pollCounter) {
            revert PollNotFound();
        }
        
        PollInfo storage poll = polls[_pollId];
        uint256 optionsLength = poll.options.length;
        
        descriptions = new string[](optionsLength);
        voteCounts = new uint256[](optionsLength);
        percentages = new uint256[](optionsLength);
        
        for (uint256 i = 0; i < optionsLength; i++) {
            descriptions[i] = poll.options[i].description;
            voteCounts[i] = poll.options[i].voteCount;
            
            if (poll.totalVotes > 0) {
                percentages[i] = (poll.options[i].voteCount * 10000) / poll.totalVotes;
            } else {
                percentages[i] = 0;
            }
        }
        
        return (descriptions, voteCounts, percentages);
    }
}