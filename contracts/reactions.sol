pragma solidity ^0.8.15;

//a simple contract to record reactions for the listings in a TCR.
// These are similar to reactions to a post in a social network
// No tokenomics used, just a mere like, love, etc.
// Atm, these emotions are target to the music artists
contract Reactions{


    //MEMBERS

    // there is no need of this enum other than making code more readable
    // in alternative, integers can just do the work.
    enum Emotion{
        emotion_1,
        emotion_2,
        emotion_3,
        emotion_4,
        emotion_5,
        emotion_6,
        emotion_7,
        emotion_8
    }

    //maps 1 artist to N reactions
    mapping (address => Emotion[]) public reactions;

    //maps 1 artist to N fans
    mapping (address => address[]) public fans;


    //EVENTS
    event ReactionAdded(address, address, Emotion);

    //VIEWS 

    function noOfReactions(address artist) public view returns(uint){
        return reactions[artist].length;
    }



    function isFanOf(address fan, address artist) public view returns(bool){
        for(uint k=0; k<fans[artist].length; k++){
            if(fans[artist][k] == fan) return true;
        }
        return false;
    }

    //TRANSACTIONS

    function addReaction(address _artist, Emotion _em) public{
        // cant' vote twice
        require(!isFanOf(msg.sender, _artist),"can't upvote twice");
        reactions[_artist].push(_em);
        fans[_artist].push(msg.sender);
        emit ReactionAdded(_artist, msg.sender, _em);
    }


}
