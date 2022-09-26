var reactionsContract = artifacts.require("Reactions");

const Emotion={
    emotion_1:0,
    emotion_2:1,
    emotion_3:2,
    emotion_4:3
}

contract('Reactions', async function (accounts) {
    let reactions;
    let [fan1,fan2,artist1,artist2] = accounts;

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
});