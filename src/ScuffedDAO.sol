// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.17;

import "src/Governance.sol";

interface IScuffie {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title scuffed dao
/// @author scuffie 10
/// @notice feeling cute. might delete later.
/// also don't use this. i didn't even write tests.
contract ScuffedDAO {

    /// @notice scuffie contract.
    IScuffie public scuffie;

    /// @notice maps proposal id's to proposals.
    mapping(uint256 => Proposal) public proposals;

    /// @notice maps proposal id's.
    mapping(uint256 => VoteRecord) public voteRecords;

    /// @notice next proposal id.
    uint256 internal nextProposalId;

    /// @notice logged when proposal is made.
    /// @param proposer caller of the proposal.
    /// @param proposalId proposal id.
    /// @param start start time.
    /// @param end end time.
    /// @param target target address to call on if passes.
    /// @param value msg value to send to target.
    /// @param payload bytes to send to target.
    event LogProposal(
        address indexed proposer,
        uint256 indexed proposalId,
        uint64 start,
        uint64 end,
        address target,
        uint256 value,
        bytes payload
    );

    /// @notice logged when vote is made.
    /// @param proposalId proposal id.
    /// @param tokenId token id that voted.
    /// @param inFavor true if vote is in favor.
    event LogVote(
        uint256 indexed proposalId,
        uint256 indexed tokenId,
        bool indexed inFavor
    );

    /// @notice logged when executed.
    /// @param proposalId proposal id.
    /// @param retData return data from the call.
    event LogExecuted(
        uint256 indexed proposalId,
        bytes retData
    );

    /// @notice proposes something.
    /// @dev reverts if invalid time frame.
    /// @param start start time.
    /// @param end end time.
    /// @param target target address to call on if passes.
    /// @param value msg value to send to target.
    /// @param payload bytes to send to target.
    /// @return proposalId proposal id.
    function propose(
        uint64 start,
        uint64 end,
        address target,
        uint256 value,
        bytes calldata payload
    ) external returns (uint256 proposalId) {
        // validate.
        if (end < start + minTimeFrame) revert InvalidTimeFrame();

        // cache proposal id.
        proposalId = nextProposalId;

        // set init values.
        proposals[proposalId].init(start, end, target, value, payload);

        // increment proposal id.
        nextProposalId = proposalId + 1;

        // log.
        emit LogProposal(msg.sender, proposalId, start, end, target, value, payload);
    }

    /// @notice votes on a proposal.
    /// @dev reverts if vote is inactive, caller is not token holder, or if token id has voted.
    /// @param proposalId proposal id to vote on.
    /// @param tokenId token id to vote with.
    /// @param inFavor true if in favor.
    function vote(uint256 proposalId, uint256 tokenId, bool inFavor) external {
        // load.
        Proposal storage proposal = proposals[proposalId];
        VoteRecord storage voteRecord = voteRecords[proposalId];

        // revert if not active.
        if (!proposal.isActive()) revert VoteNotActive();
        // revert if not owner of token id.
        if (scuffie.ownerOf(tokenId) != msg.sender) revert Unauthorized(msg.sender);

        // validate token id has not voted.
        if (voteRecord.hasVoted(tokenId)) revert HasVoted(tokenId);

        // set has voted.
        voteRecord.setHasVoted(tokenId);

        // increment the appropriate count.
        inFavor ? proposal.incrementInFavor() : proposal.incrementAgainst();

        // log.
        emit LogVote(proposalId, tokenId, inFavor);
    }

    /// @notice executes a proposal.
    /// @dev reverts if vote is active, the result is not valid, execution has happened, or
    /// execution fails.
    /// @param proposalId proposal id to execute from.
    function executeProposal(uint256 proposalId) external {
        // load.
        Proposal storage proposal = proposals[proposalId];

        // revert if active.
        if (proposal.isActive()) revert VoteActive();
        // revert if not explicitly passed (this will also revert if the propsal does not exist).
        if (proposal.result() != Result.Passed) revert ResultNotValid();
        // revert if has been executed.
        if (proposal.executed) revert Executed();

        // make the call.
        (bool success, bytes memory retData) = proposal.execute();

        // if call fails, revert, bubbling up data.
        if (!success) revert ExecutionFailed(retData);

        // log.
        emit LogExecuted(proposalId, retData);
    }
}
