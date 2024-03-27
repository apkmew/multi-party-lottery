// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.2 <0.9.0;

import "./CommitReveal.sol";
import "./Ownership.sol";

contract MultiPartyLottery is CommitReveal, Ownership {

    // Time for each stage
    uint public StartTime;  // Start Time
    uint public T1;         // Stage 1 : Commit Stage Duration
    uint public T2;         // Stage 2 : Reveal Stage Duration
    uint public T3;         // Stage 3 : Finding Winner Stage Duration
    
    // Number of players
    uint public N;          // Max Number of players
    uint public currentN;   // Current Number of players

    // Current stage
    uint public currentStage = 0;

    // Constant
    uint constant minChoice = 0;
    uint constant maxChoice = 999;
    uint constant lotteryFee = 0.001 ether;

    struct Player {
        uint choice;
        bool isCommited;
        bool isRevealed;
        bool isWithdrawn;
        address addr;
    }

    mapping( uint => Player ) players;

    // Initial variable
    constructor( uint _N, uint _T1, uint _T2, uint _T3 ) {
        N = _N;
        T1 = _T1;
        T3 = _T2;
        T1 = _T3;
    }

    function getCurrentStage() public view returns ( string memory, uint ) {
        if( currentStage == 0 ){
            return ( "Idle", 0 );
        }
        else if( currentStage == 1 ){

            // Commit Stage
            if( block.timestamp < StartTime + T1 ){
                return ( "Current Stage: Commit\nTime Remaining (secconds): ", StartTime + T1 - block.timestamp );
            }

            // Reveal Stage
            else if( block.timestamp < StartTime + T1 + T2 ){
                return ( "Current Stage: Reveal\nTime Remaining (secconds): ", StartTime + T1 + T2 - block.timestamp );
            }

            // Finding Winner Stage
            else if( block.timestamp < StartTime + T1 + T2 + T3 ){
                return ( "Current Stage: Finding Winner\nTime Remaining (secconds): ", StartTime + T1 + T2 + T3 - block.timestamp );
            }

            // Withdraw Stage
            else{
                return ( "Current Stage: Withdraw Stage, you can withdraw your ETH now\n", 0 );
            }
        }
    }

    function getHashChoice( uint choice, string memory salt ) external pure returns ( bytes32 ) {
        bytes32 encodeSalt = bytes32( abi.encodePacked( salt ) );
        return keccak256( abi.encodePacked( choice, encodeSalt ) );
    }

    function commitHashedChoice( bytes32 hashedChoice ) public payable returns ( uint ) {
        require( msg.value == lotteryFee, "Require 0.001 ETH for Lottery fee" );
        require( currentN < N, "The number of players is complete" );

        // Check for first player
        if( currentStage == 0 ){
            currentStage = 1;
            StartTime = block.timestamp;
        }

        require( block.timestamp < StartTime + T1, "Commit Stage has expired" );

        uint idx = currentN;

        commit( getHash( hashedChoice ) );

        players[idx].choice = 0;
        players[idx].isCommited = true;
        players[idx].isRevealed = false;
        players[idx].isWithdrawn = false;
        players[idx].addr = msg.sender;

        currentN++;

        return idx;
    }

    function revealChoice( uint _idx, uint _choice, string memory _salt ) public {
        require( StartTime + T1 < block.timestamp && block.timestamp < StartTime + T1 + T2, "Out of Reveal Stage period" );
        require( msg.sender == players[_idx].addr, "Wrong Index" );

        bytes32 encodeSalt = bytes32( abi.encodePacked( _salt ) );
        reveal( keccak256( abi.encodePacked( _choice, encodeSalt ) ) );

        players[_idx].choice = _choice;
        players[_idx].isRevealed = true;
    }

    function findWinner() public onlyOwner {
        require( StartTime + T1 + T2 < block.timestamp && block.timestamp < StartTime + T1 + T2 + T3 );

        Player[] memory goodPlayers = new Player[]( currentN );
        uint goodPlayersCount;

        for( uint i = 0 ; i < currentN ; i++ ){
            if( players[i].isRevealed && minChoice <= players[i].choice && players[i].choice <= maxChoice ){
                goodPlayers[goodPlayersCount].choice = players[i].choice;
                goodPlayers[goodPlayersCount].isCommited = players[i].isCommited;
                goodPlayers[goodPlayersCount].isRevealed = players[i].isRevealed;
                goodPlayers[goodPlayersCount].isWithdrawn = players[i].isWithdrawn;
                goodPlayersCount++;
            }
            else{
                uint returnMoney = ( lotteryFee * 98 ) / 100;
                uint ownerFee = ( lotteryFee * 2 ) / 100;
                
                payable( players[i].addr ).transfer( returnMoney );
                payable( owner() ).transfer( ownerFee );
            }
        }

        if( goodPlayersCount == 0 ){
            _ownerClaimAllReward();
        }

        uint xorChoice = goodPlayers[0].choice;
        for( uint i = 1 ; i < goodPlayersCount ; i++ ){
            xorChoice = xorChoice ^ goodPlayers[i].choice;
        }
        uint winnerIdx = uint( keccak256( abi.encodePacked( xorChoice ) ) ) % goodPlayersCount;
        
        _rewardWinner( goodPlayers[winnerIdx].addr, goodPlayersCount );
        _resetGame();
    }

    function _ownerClaimAllReward() private {
        uint ownerFee = lotteryFee * currentN;
        payable( owner() ).transfer( ownerFee );
    }

    function _rewardWinner( address _winnerAddr, uint goodPlayerN ) private {
        uint winnerReward = ( lotteryFee * goodPlayerN * 98 ) / 100;
        uint ownerFee = ( lotteryFee * goodPlayerN * 2 ) / 100;

        payable( _winnerAddr ).transfer( winnerReward );
        payable( owner() ).transfer( ownerFee );
    }

    function withdraw( uint idx ) public {
        require( block.timestamp > StartTime + T1 + T2 + T3, "Out of withdraw period" );
        require( msg.sender == players[idx].addr, "Wrong Index" );
        require( players[idx].isWithdrawn == false );

        players[idx].isWithdrawn = true;
        payable( msg.sender ).transfer( lotteryFee );

        currentN--;

        if( currentN == 0 ){
            _resetGame();
        }
    }

    function _resetGame() private {
        currentStage = 0;
        currentN = 0;
        StartTime = block.timestamp;
    }

}