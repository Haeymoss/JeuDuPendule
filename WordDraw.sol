pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PendulumWordDraw is VRFConsumerBase, Ownable {
    bytes32 internal keyHash;
    uint256 internal fee;

    mapping(uint256 => string) public randomWords;
    mapping(bytes32 => uint256) private requestToSessionId;

    string[] private wordList;

    event WordDrawn(uint256 indexed sessionId, string word);

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        keyHash = _keyHash;
        fee = _fee;

        // Initialize word list (example words)
        wordList = ["apple", "banana", "cherry", "date", "elderberry"];
    }

    function requestRandomWord(uint256 _sessionId) external {
        require(randomWords[_sessionId] == "", "Word already drawn");
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK balance"
        );

        bytes32 requestId = requestRandomness(keyHash, fee);
        requestToSessionId[requestId] = _sessionId;
    }

    function fulfillRandomness(
        bytes32 _requestId,
        uint256 _randomness
    ) internal override {
        uint256 sessionId = requestToSessionId[_requestId];
        uint256 wordIndex = _randomness % wordList.length;
        string memory word = wordList[wordIndex];

        randomWords[sessionId] = word;
        emit WordDrawn(sessionId, word);

        delete requestToSessionId[_requestId];
    }

    function addWord(string memory _word) external onlyOwner {
        wordList.push(_word);
    }

    function getWordListLength() external view returns (uint256) {
        return wordList.length;
    }

    function withdrawLink() external onlyOwner {
        uint256 balance = LINK.balanceOf(address(this));
        require(LINK.transfer(owner(), balance), "Unable to transfer");
    }
}

/*
The contract inherits from VRFConsumerBase, which is a Chainlink contract that provides the functionality for requesting and receiving random numbers.
It uses two main state variables:

keyHash: A unique identifier for the VRF job
fee: The amount of LINK tokens required to pay for a VRF request


It has a public mapping randomWords that stores the generated random words, keyed by a session ID.
An event WordDrawn is defined to emit when a new word is drawn.
The constructor initializes the VRF consumer base and sets the keyHash and fee.
The requestRandomWord function:

Checks if a word has already been drawn for the given session ID
Ensures the contract has enough LINK tokens to pay for the VRF request
Calls requestRandomness to initiate a VRF request


The fulfillRandomness function is a callback that will be called by the Chainlink VRF when the random number is ready. It's supposed to generate a random word based on the received random number.

Overall, the structure is sound, but there are a few things to note:

The code is incomplete. The generateRandomWord function is not implemented, and there's a comment indicating that the requestId should be stored for later verification.
The fulfillRandomness function doesn't store the generated word or emit the WordDrawn event.
There's no function to withdraw LINK tokens if needed.

To complete this contract, you would need to:

Implement the generateRandomWord function
Store the requestId in the requestRandomWord function
Complete the fulfillRandomness function to store the word and emit the event
Add a function to withdraw LINK tokens (for maintenance)








Added the OpenZeppelin Ownable contract to manage access control.
Implemented a wordList array to store the list of words that can be randomly selected.
Added a requestToSessionId mapping to keep track of which session ID corresponds to each VRF request.
Completed the fulfillRandomness function:

It retrieves the session ID for the request
Selects a random word from the wordList using the provided randomness
Stores the word in the randomWords mapping
Emits the WordDrawn event
Cleans up the requestToSessionId mapping


Added an addWord function that allows the owner to add new words to the wordList.
Added a getWordListLength function to check the number of words in the list.
Implemented a withdrawLink function to allow the owner to withdraw any LINK tokens from the contract.
*/
