// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PendulumGame {
    uint256 private constant MAX_GUESSES = 6;
    uint256 private sessionCounter = 0;

    // Struct to represent a game session
    struct Session {
        uint256 sessionId;
        address player1;
        address player2;
        uint256 betAmount;
        bytes32 wordHash;
        string word;
        bool isWordRevealed;
        bool isSessionClosed;
        uint256 guessesLeft;
        mapping(bytes1 => bool) guessedLetters;
    }

    // Mapping to store game sessions
    mapping(uint256 => Session) public sessions;

    // Event declarations
    event SessionCreated(
        uint256 indexed sessionId,
        address indexed player1,
        uint256 betAmount
    );
    event SessionJoined(uint256 indexed sessionId, address indexed player2);
    event WordRevealed(uint256 indexed sessionId);
    event GuessMade(
        uint256 indexed sessionId,
        address indexed player,
        string guess,
        bool correct,
        uint256 guessesLeft
    );
    event SessionClosed(
        uint256 indexed sessionId,
        address indexed winner,
        uint256 winnings
    );

    // Modifiers to restrict access to certain functions
    modifier onlyPlayer1(uint256 _sessionId) {
        require(
            msg.sender == sessions[_sessionId].player1,
            "Only player1 can perform this action"
        );
        _;
    }
    // Modifier to restrict access to player2
    modifier onlyPlayer2(uint256 _sessionId) {
        require(
            msg.sender == sessions[_sessionId].player2,
            "Only player2 can perform this action"
        );
        _;
    }
    // Modifier to check if a session exists
    modifier sessionExists(uint256 _sessionId) {
        require(
            sessions[_sessionId].player1 != address(0),
            "Session does not exist"
        );
        _;
    }
    // Modifier to check if a session is not closed
    modifier sessionNotClosed(uint256 _sessionId) {
        require(
            !sessions[_sessionId].isSessionClosed,
            "Session is already closed"
        );
        _;
    }

    /* The createSession function uses block.timestamp and msg.sender to generate a session ID. While this approach works, it might be vulnerable to miner manipulation. Consider using a more robust method for generating unique IDs.*/
    // Function to create a new game session
    function createSession(bytes32 _wordHash) external payable {
        require(msg.value > 0, "Bet amount must be greater than 0");

        sessionCounter++;
        uint256 sessionId = sessionCounter;

        Session storage newSession = sessions[sessionId];
        newSession.sessionId = sessionId;
        newSession.player1 = msg.sender;
        newSession.betAmount = msg.value;
        newSession.wordHash = _wordHash;
        newSession.guessesLeft = MAX_GUESSES;

        emit SessionCreated(sessionId, msg.sender, msg.value);
    }

    /*The joinSession function correctly checks if the session is already joined and if the bet amount is correct. Consider adding a check to ensure the session exists before allowing a join.*/
    // Function for a player to join an existing game session
    function joinSession(
        uint256 _sessionId
    ) external payable sessionExists(_sessionId) sessionNotClosed(_sessionId) {
        Session storage session = sessions[_sessionId];
        require(session.player2 == address(0), "Session already joined");
        require(msg.value == session.betAmount, "Incorrect bet amount");

        session.player2 = msg.sender;
        emit SessionJoined(_sessionId, msg.sender);
    }

    /*The revealWord function correctly restricts access to player1. Consider adding a check to ensure the word hasn't been revealed already.*/
    // Function to reveal the word for a game session
    function revealWord(
        uint256 _sessionId,
        string memory _word
    )
        external
        sessionExists(_sessionId)
        sessionNotClosed(_sessionId)
        onlyPlayer1(_sessionId)
    {
        Session storage session = sessions[_sessionId];
        require(!session.isWordRevealed, "Word already revealed");
        require(
            keccak256(abi.encodePacked(_word)) == session.wordHash,
            "Revealed word does not match the hash"
        );

        session.word = _word;
        session.isWordRevealed = true;
        emit WordRevealed(_sessionId);
    }

    /* The makeGuess function is incomplete. You'll need to implement the logic for checking guesses and updating the game state.*/
    // Function for a player to make a guess
    function makeGuess(
        uint256 _sessionId,
        string memory _guess
    )
        external
        sessionExists(_sessionId)
        sessionNotClosed(_sessionId)
        onlyPlayer2(_sessionId)
    {
        Session storage session = sessions[_sessionId];
        require(session.isWordRevealed, "Word not revealed yet");
        require(session.guessesLeft > 0, "No guesses left");

        bool correct = false;
        if (
            keccak256(abi.encodePacked(_guess)) ==
            keccak256(abi.encodePacked(session.word))
        ) {
            correct = true;
        } else if (bytes(_guess).length == 1) {
            bytes1 guessedLetter = bytes(_guess)[0];
            if (!session.guessedLetters[guessedLetter]) {
                session.guessedLetters[guessedLetter] = true;
                if (
                    bytes(session.word).length > 0 &&
                    contains(session.word, guessedLetter)
                ) {
                    correct = true;
                } else {
                    session.guessesLeft--;
                }
            }
        } else {
            session.guessesLeft--;
        }

        emit GuessMade(
            _sessionId,
            msg.sender,
            _guess,
            correct,
            session.guessesLeft
        );

        if (correct || session.guessesLeft == 0) {
            closeSession(_sessionId);
        }
    }

    /* The closeSession function has good access control but might have some logical issues:
It always sets the winner to the opposite of who called the function if the word is revealed.
It doesn't check if the game is actually finished (all guesses used or word guessed correctly).*/
    // Function to close a game session and distribute funds
    function closeSession(
        uint256 _sessionId
    ) public sessionExists(_sessionId) sessionNotClosed(_sessionId) {
        Session storage session = sessions[_sessionId];
        require(
            msg.sender == session.player1 || msg.sender == session.player2,
            "Not authorized"
        );

        address winner;
        if (!session.isWordRevealed) {
            // If word not revealed, refund the bet amount to both players
            payable(session.player1).transfer(session.betAmount);
            if (session.player2 != address(0)) {
                payable(session.player2).transfer(session.betAmount);
            }
        } else if (session.guessesLeft == 0) {
            winner = session.player1;
        } else {
            winner = session.player2;
        }

        if (winner != address(0)) {
            uint256 winnings = session.betAmount * 2;
            payable(winner).transfer(winnings);
            emit SessionClosed(_sessionId, winner, winnings);
        }

        session.isSessionClosed = true;
    }

    // Function to get the state of a game session
    function getSessionState(
        uint256 _sessionId
    )
        external
        view
        sessionExists(_sessionId)
        returns (
            address player1,
            address player2,
            uint256 betAmount,
            bool isWordRevealed,
            bool isSessionClosed,
            uint256 guessesLeft
        )
    {
        Session storage session = sessions[_sessionId];
        return (
            session.player1,
            session.player2,
            session.betAmount,
            session.isWordRevealed,
            session.isSessionClosed,
            session.guessesLeft
        );
    }

    // Function to check if a word contains a specific letter
    function contains(
        string memory _word,
        bytes1 _letter
    ) private pure returns (bool) {
        bytes memory wordBytes = bytes(_word);
        for (uint i = 0; i < wordBytes.length; i++) {
            if (wordBytes[i] == _letter) {
                return true;
            }
        }
        return false;
    }
}

/* 
General Improvements:

Consider adding more detailed error messages in require statements.
Implement a function to check the current state of a session.
Add a way to handle timeouts or abandoned games.
Consider implementing a way to verify that the revealed word matches the initially committed word (e.g., using a hash commitment scheme).


Security Considerations:

The contract is handling ether, so it's crucial to ensure all state changes and ether transfers are secure.
Consider using the "pull payment" pattern instead of directly transferring ether.
Add checks for reentrancy vulnerabilities, especially in the closeSession function.


Gas Optimization:

Consider using uint256 instead of uint for consistency and potential gas savings.
The Session struct could be optimized by reordering fields to pack them more efficiently.
*/
