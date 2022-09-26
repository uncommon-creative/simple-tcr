var reactionsContract = artifacts.require("Reactions");

const Emotion={
    emotion_1:0,
    emotion_2:1,
    emotion_3:2,
    emotion_4:3
}

contract('Reactions', async function (accounts) {
    let reactions;
    let [fan1,fan2,fan3,artist1,artist2] = accounts;

    before(async () => {
        reactions = await reactionsContract.new();
    });

    it("a fan can upvote an artist", async function () {
        await reactions.addReaction(artist1,Emotion.emotion_1);
        let r = await reactions.reactions(artist1,0);
        assert.equal(r,Emotion.emotion_1);
    });

    it("same fan cannot upvote an artist twice", async function () {
        
        try{
            await reactions.addReaction(artist1,Emotion.emotion_1);
        }
        catch(err){
            assert(err != undefined);
        }
        
    });    

    it("artist gets upvote from another fan", async function () {
        await reactions.addReaction(artist1,Emotion.emotion_2, {from: fan2});
        let r = await reactions.reactions(artist1,1);
        assert.equal(r,Emotion.emotion_2);
    });       

    it("artist no of upvotes is now two", async function () {
       
        let N = await reactions.noOfReactions(artist1);
        assert.equal(N,2);

        await reactions.addReaction(artist1,Emotion.emotion_2, {from: fan3});
        N = await reactions.noOfReactions(artist1);
        assert.equal(N,3);
    });       


});