pragma solidity ^0.8.7;

interface IERC20 {
    function transfer(address _to, uint256 _value) external returns (bool success);
}
// this contract sends tokens to any msg.sender where msg.value == 0.
// it's like a faucet, but for tokens.
// msg.sender still has to pay gas though
contract ERC20Faucet{
    IERC20 public token;
    constructor(address _token){
        token= IERC20(_token);
    }

    receive () external payable {
        require(msg.value==0,"Thanks but no, send zero ether please");
        token.transfer(msg.sender, 1000000);
    }
}