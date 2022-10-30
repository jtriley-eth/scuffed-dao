// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.17;

// re-export this here.
import "src/VoteRecord.sol";

// caller is not authorized to do whatever they're trying to do.
error Unauthorized(address badKiddo);
// token id has already been used to vote.
error HasVoted(uint256 id);
// invalid time frame.
error InvalidTimeFrame();
// vote is active.
error VoteActive();
// vote is not active.
error VoteNotActive();
// result is not valid.
error ResultNotValid();
// payload has been executed against target.
error Executed();
// payload execution against target has failed.
error ExecutionFailed(bytes revertData);

// proposal data.
struct Proposal {
    // start time of the proposal.
    uint64 start;
    // end time of the proposal.
    uint64 end;
    // votes in favor.
    uint16 inFavor;
    // votes against.
    uint16 against;
    // executed.
    bool executed;
    // target address.
    address target;
    // ether amount to send.
    uint256 value;
    // payload to call against target.
    bytes payload;
}

// proposal result.
enum Result {
    // not finalized.
    NotFinalized,
    // failed.
    Failed,
    // passed.
    Passed,
    // tie.
    Tie
}

uint64 constant minTimeFrame = uint64(604800);

// initializes the proposal
function init(
    Proposal storage proposal, 
    uint64 start,
    uint64 end,
    address target,
    uint256 value,
    bytes calldata payload
) {
    proposal.start = start;
    proposal.end = end;
    proposal.target = target;
    proposal.value = value;
    proposal.payload = payload;
}

// returns true if active.
function isActive(Proposal storage proposal) view returns (bool) {
    uint64 timestamp = uint64(block.timestamp);
    return proposal.start <= timestamp && timestamp < proposal.end;
}

// increments inFavor count.
function incrementInFavor(Proposal storage proposal) {
    // this will never overflow as the max votes will only ever be 1344.
    unchecked {
        proposal.inFavor += 1;
    }
}

// increments the against count.
function incrementAgainst(Proposal storage proposal) {
    // this will never overflow as the max votes will only ever be 1344.
    unchecked {
        proposal.against += 1;
    }
}

// returns the result.
function result(Proposal storage proposal) view returns (Result res) {
    // cache to reduce reads
    uint16 inFavor = proposal.inFavor;
    uint16 against = proposal.against;

    // tie
    if (inFavor == against) return inFavor == 0 ? Result.NotFinalized : Result.Tie;
    // pass
    else if (inFavor > against) return Result.Passed;
    // fail
    return Result.Failed;
}

// executes against the target.
function execute(Proposal storage proposal) returns (bool success, bytes memory retData) {
    // make the call with the value.
    (success, retData) = proposal.target.call{value: proposal.value}(proposal.payload);

    // set executed to true.
    proposal.executed = success;
}

using { init, isActive, incrementInFavor, incrementAgainst, result, execute } for Proposal global;
