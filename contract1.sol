/* Code exo ratrappage

    Vous aurez besoin de plusieurs contrats intelligents pour gérer les différentes fonctionnalités :
        
    1 Contrat de gestion du jeu (PendulumGame) :
        Ce contrat gère la création de sessions, la gestion des tours, la vérification des mots et la clôture des sessions.
        Il stocke les informations sur les sessions, les joueurs, les mises, etc.
        Il inclut des fonctions pour créer une session, rejoindre une session, révéler le mot, deviner une lettre ou un mot, et clôturer la session.

    2 Contrat de gestion des sessions (PendulumSessionManager) :
        Ce contrat stocke les informations sur les sessions de jeu.
        Il inclut des fonctions pour créer et rejoindre des sessions.

    3 Contrat de tirage au sort du mot (PendulumWordDraw) :
        Ce contrat utilise Chainlink VRF pour générer un mot aléatoire.
        Il stocke les mots aléatoires générés.

    4 Contrat de gestion des gains et des pertes :
        Ce contrat gère la distribution des fonds aux gagnants.
        Il inclut une fonction pour clôturer la session et distribuer les gains.

*/

// 1 Contrat de gestion du jeu (PendulumGame)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PendulumGame {
    // Struct to store information about a session
    struct Session {
        uint256 sessionId;
        address player1;
        address player2;
        uint256 betAmount;
        string word;
        bool isWordRevealed;
        bool isSessionClosed;
    }

    // Mapping to store sessions
    mapping(uint256 => Session) public sessions;

    // Event emitted when a new session is created
    event SessionCreated(
        uint256 indexed sessionId,
        address indexed player1,
        uint256 betAmount
    );
    event WordRevealed(uint256 indexed sessionId, string word);
    event GuessMade(
        uint256 indexed sessionId,
        address indexed player,
        string guess
    );
    event SessionClosed(
        uint256 indexed sessionId,
        address indexed winner,
        uint256 winnings
    );

    // Function to create a new session
    function createSession(uint256 _betAmount) external {
        uint256 sessionId = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender))
        );
        sessions[sessionId] = Session(
            sessionId,
            msg.sender,
            address(0),
            _betAmount,
            "",
            false,
            false
        );
        emit SessionCreated(sessionId, msg.sender, _betAmount);
    }

    // Function to join an existing session
    function joinSession(uint256 _sessionId) external payable {
        Session storage session = sessions[_sessionId];
        require(session.player2 == address(0), "Session already joined");
        require(msg.value == session.betAmount, "Incorrect bet amount");
        session.player2 = msg.sender;
    }

    // Function to reveal the word by player1
    function revealWord(uint256 _sessionId, string memory _word) external {
        Session storage session = sessions[_sessionId];
        require(
            msg.sender == session.player1,
            "Only player1 can reveal the word"
        );
        session.word = _word;
        session.isWordRevealed = true;
        emit WordRevealed(_sessionId, _word);
    }

    // Function to guess a letter or word by player2
    function makeGuess(uint256 _sessionId, string memory _guess) external {
        Session storage session = sessions[_sessionId];
        require(msg.sender == session.player2, "Only player2 can guess");
        require(session.isWordRevealed, "Word not revealed yet");
        emit GuessMade(_sessionId, msg.sender, _guess);
        // Implement logic to check if the guess is correct
        // Update session state (e.g., draw the pendulum, check if player2 wins, etc.)
        // ...
    }

    // Function to close the session and distribute funds
    function closeSession(uint256 _sessionId) external {
        Session storage session = sessions[_sessionId];
        require(session.isSessionClosed == false, "Session already closed");
        require(
            msg.sender == session.player1 || msg.sender == session.player2,
            "Not authorized"
        );

        address winner;
        if (session.isWordRevealed) {
            if (msg.sender == session.player1) {
                winner = session.player2;
            } else {
                winner = session.player1;
            }
        } else {
            // If word not revealed, refund the bet amount to both players
            payable(session.player1).transfer(session.betAmount);
            payable(session.player2).transfer(session.betAmount);
        }

        if (winner != address(0)) {
            // Distribute the winnings (entire bet amount) to the winner
            uint256 winnings = session.betAmount * 2;
            payable(winner).transfer(winnings);
            emit SessionClosed(_sessionId, winner, winnings);
        }

        session.isSessionClosed = true;
    }
}

// 2 Contrat de gestion des sessions (PendulumSessionManager)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PendulumSessionManager {
    // Struct to store information about a session
    struct Session {
        uint256 sessionId;
        address player1;
        address player2;
        uint256 betAmount;
        string word;
        bool isWordRevealed;
        bool isSessionClosed;
    }

    // Mapping to store sessions
    mapping(uint256 => Session) public sessions;

    // Event emitted when a new session is created
    event SessionCreated(
        uint256 indexed sessionId,
        address indexed player1,
        uint256 betAmount
    );

    // Modifier to check if the session exists and is open
    modifier sessionExistsAndOpen(uint256 _sessionId) {
        require(
            sessions[_sessionId].player1 != address(0),
            "Session does not exist"
        );
        require(!sessions[_sessionId].isSessionClosed, "Session is closed");
        _;
    }

    // Function to create a new session
    function createSession(uint256 _betAmount) external {
        uint256 sessionId = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender))
        );
        sessions[sessionId] = Session(
            sessionId,
            msg.sender,
            address(0),
            _betAmount,
            "",
            false,
            false
        );
        emit SessionCreated(sessionId, msg.sender, _betAmount);
    }

    // Function to join an existing session
    function joinSession(
        uint256 _sessionId
    ) external payable sessionExistsAndOpen(_sessionId) {
        require(
            sessions[_sessionId].player2 == address(0),
            "Session already joined"
        );
        require(
            msg.value == sessions[_sessionId].betAmount,
            "Incorrect bet amount"
        );
        sessions[_sessionId].player2 = msg.sender;
    }
}

// 3 Contrat de tirage au sort du mot (PendulumWordDraw)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract PendulumWordDraw is VRFConsumerBase {
    // Variables for Chainlink VRF
    bytes32 internal keyHash;
    uint256 internal fee;

    // Mapping to store random words
    mapping(uint256 => string) public randomWords;

    // Event emitted when a new word is drawn
    event WordDrawn(uint256 indexed sessionId, string word);

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        keyHash = _keyHash;
        fee = _fee;
    }

    // Function to request a random word
    function requestRandomWord(uint256 _sessionId) external {
        require(randomWords[_sessionId] == "", "Word already drawn");
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK balance"
        );
        bytes32 requestId = requestRandomness(keyHash, fee);
        // Store the requestId for later verification
        // ...
    }

    // Callback function when random word is generated
    function fulfillRandomness(
        bytes32 _requestId,
        uint256 _randomWordIndex
    ) internal override {
        // Generate a random word (e.g., from a predefined list)
        string memory word = generateRandomWord(_randomWordIndex);
        randomWords[_randomWordIndex] = word;
        emit WordDrawn(_randomWordIndex, word);
    }

    // Implement your logic to generate a random word (e.g., from a predefined list)
    function generateRandomWord(
        uint256 _randomWordIndex
    ) internal pure returns (string memory) {
        // ...
    }
}

// 4 Contrat de gestion des gains et des pertes
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PendulumGame {
    // Struct to store information about a session
    struct Session {
        uint256 sessionId;
        address player1;
        address player2;
        uint256 betAmount;
        string word;
        bool isWordRevealed;
        bool isSessionClosed;
    }

    // Mapping to store sessions
    mapping(uint256 => Session) public sessions;

    // Function to close the session and distribute funds
    function closeSession(uint256 _sessionId) external {
        Session storage session = sessions[_sessionId];
        require(session.isSessionClosed == false, "Session already closed");
        require(
            msg.sender == session.player1 || msg.sender == session.player2,
            "Not authorized"
        );

        address winner;
        if (session.isWordRevealed) {
            if (msg.sender == session.player1) {
                winner = session.player2;
            } else {
                winner = session.player1;
            }
        } else {
            // If word not revealed, refund the bet amount to both players
            payable(session.player1).transfer(session.betAmount);
            payable(session.player2).transfer(session.betAmount);
        }

        if (winner != address(0)) {
            // Distribute the winnings (entire bet amount) to the winner
            uint256 winnings = session.betAmount * 2;
            payable(winner).transfer(winnings);
        }

        session.isSessionClosed = true;
    }
}
