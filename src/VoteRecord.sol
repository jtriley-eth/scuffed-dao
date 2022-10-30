// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.17;

// bitmap is just a compile-time abstraction to explain wtf the slots are.
type Bitmap is uint256;

// vote record holds 6 uint256 values (total of 1536 bits).
// the token id count is hard coded to be 1344, which means token id's can be
// used as indices to a 1536 bit chunk.
struct VoteRecord {
    Bitmap slot0;
    Bitmap slot1;
    Bitmap slot2;
    Bitmap slot3;
    Bitmap slot4;
    Bitmap slot5;
}

// word size in bits.
uint256 constant wordSize = 256;

// one.
uint256 constant one = 1;

// returns true if the token id is marked as voted (or 1).
function hasVoted(VoteRecord storage voteRecord, uint256 id) view returns (bool voted) {
    // rounds down to the slot index.
    uint256 slotIndex = id / wordSize;
    // gives index within the slot.
    uint256 bitmapIndex = id % wordSize;
    assembly {
        // load the bitmap based on slot index.
        // check if the bit at the bitmap index non-zero.
        voted := iszero(iszero(and(sload(add(slotIndex, voteRecord.slot)), shl(bitmapIndex, 1))))
    }
}

// sets the vote record for a token id to true (or 1).
function setHasVoted(VoteRecord storage voteRecord, uint256 id) {
    // rounds down to the slot index.
    uint256 slotIndex = id / wordSize;
    // gives index within the slot.
    uint256 bitmapIndex = id % wordSize;
    assembly {
        // load the bitmap based on slot index.
        // set the bit to one and store it.
        let slot := add(slotIndex, voteRecord.slot)
        sstore(slot, or(sload(slot), shl(bitmapIndex, one)))
    }
}

using { hasVoted, setHasVoted } for VoteRecord global;
