// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PendulumSessionManager is ReentrancyGuard {
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

    // Counter for generating unique session IDs
    uint256 private sessionCounter;

    // Events
    event SessionCreated(uint256 indexed sessionId, address indexed player1, uint256 betAmount);
    event SessionJoined(uint256 indexed sessionId, address indexed player2);
    event SessionClosed(uint256 indexed sessionId, address winner);

    // Custom errors
    error SessionDoesNotExist(uint256 sessionId);
    error SessionAlreadyClosed(uint256 sessionId);
    error SessionAlreadyJoined(uint256 sessionId);
    error IncorrectBetAmount(uint256 expected, uint256 received);
    error UnauthorizedClosure(uint256 sessionId);

    // Modifier to check if the session exists and is open
    modifier sessionExistsAndOpen(uint256 _sessionId) {
        if (sessions[_sessionId].player1 == address(0)) {
            revert SessionDoesNotExist(_sessionId);
        }
        if (sessions[_sessionId].isSessionClosed) {
            revert SessionAlreadyClosed(_sessionId);
        }
        _;
    }

    // Function to create a new session
    function createSession(uint256 _betAmount) external payable nonReentrant {
        require(msg.value == _betAmount, "Bet amount must match sent value");
        
        sessionCounter++;
        uint256 sessionId = sessionCounter;

        sessions[sessionId] = Session({
            sessionId: sessionId,
            player1: msg.sender,
            player2: address(0),
            betAmount: _betAmount,
            word: "",
            isWordRevealed: false,
            isSessionClosed: false
        });

        emit SessionCreated(sessionId, msg.sender, _betAmount);
    }

    // Function to join an existing session
    function joinSession(uint256 _sessionId) external payable nonReentrant sessionExistsAndOpen(_sessionId) {
        Session storage session = sessions[_sessionId];

        if (session.player2 != address(0)) {
            revert SessionAlreadyJoined(_sessionId);
        }
        if (msg.value != session.betAmount) {
            revert IncorrectBetAmount(session.betAmount, msg.value);
        }

        session.player2 = msg.sender;
        emit SessionJoined(_sessionId, msg.sender);
    }

    // Function to close a session and determine the winner
    function closeSession(uint256 _sessionId, address _winner) external nonReentrant sessionExistsAndOpen(_sessionId) {
        Session storage session = sessions[_sessionId];

        if (msg.sender != session.player1 && msg.sender != session.player2) {
            revert UnauthorizedClosure(_sessionId);
        }

        require(_winner == session.player1 || _winner == session.player2, "Invalid winner");

        session.isSessionClosed = true;

        uint256 totalBet = session.betAmount * 2;
        payable(_winner).transfer(totalBet);

        emit SessionClosed(_sessionId, _winner);
    }

    // Function to get session details
    function getSession(uint256 _sessionId) external view returns (Session memory) {
        return sessions[_sessionId];
    }
}





/*

Added SPDX license identifier.
Imported OpenZeppelin's ReentrancyGuard and applied nonReentrant modifier to sensitive functions.
Implemented a sessionCounter for generating unique, incrementing session IDs.
Added custom errors for more descriptive error handling.
Modified createSession to accept payment and ensure it matches the bet amount.
Added a closeSession function to handle game outcomes and transfer funds to the winner.
Implemented a getSession function to retrieve session details.
Added more events for better off-chain tracking of contract state changes.
Improved error handling throughout the contract.
Used uint256 consistently for all unsigned integers.




Session ID generation: The current method of generating session IDs could potentially lead to collisions. Consider using a more robust method or an incrementing counter.
Reentrancy protection: The contract doesn't have explicit reentrancy protection. Consider adding the nonReentrant modifier to sensitive functions.
Bet amount handling: The contract accepts the bet amount but doesn't store it. You might want to add logic to handle the actual transfer of funds.
Session closure: There's no function to close a session or handle the game's outcome. You might want to add this functionality.
Gas optimization: Consider using uint256 instead of uint for consistency and potential gas savings.
Error messages: Custom error messages could be more descriptive to aid debugging and user interaction.