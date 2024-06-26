pragma solidity ^0.8.0;

contract PendulumGame {
    struct Session {
        uint256 sessionId;
        address player1;
        address player2;
        uint256 betAmount;
        string word;
        bool isWordRevealed;
        bool isSessionClosed;
    }

    mapping(uint256 => Session) public sessions;
    mapping(address => uint256) public pendingWithdrawals;

    event SessionClosed(uint256 indexed sessionId, address winner);
    event WithdrawalRequested(address indexed player, uint256 amount);

    error SessionAlreadyClosed();
    error NotAuthorized();
    error InsufficientContractBalance();

    function closeSession(uint256 _sessionId) external {
        Session storage session = sessions[_sessionId];
        if (session.isSessionClosed) revert SessionAlreadyClosed();
        if (msg.sender != session.player1 && msg.sender != session.player2)
            revert NotAuthorized();

        session.isSessionClosed = true;

        if (session.isWordRevealed) {
            address winner = (msg.sender == session.player1)
                ? session.player2
                : session.player1;
            uint256 winnings = session.betAmount * 2;
            pendingWithdrawals[winner] += winnings;
            emit SessionClosed(_sessionId, winner);
        } else {
            pendingWithdrawals[session.player1] += session.betAmount;
            pendingWithdrawals[session.player2] += session.betAmount;
            emit SessionClosed(_sessionId, address(0));
        }
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount > 0) {
            if (amount > address(this).balance)
                revert InsufficientContractBalance();
            pendingWithdrawals[msg.sender] = 0;
            emit WithdrawalRequested(msg.sender, amount);
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Transfer failed");
        }
    }
}

/*
Functionality:

The contract manages sessions for a game where two players bet on a word being revealed.
The closeSession function handles the distribution of funds based on the game outcome.


Security:

The function checks if the session is already closed and if the caller is authorized (one of the players).
It uses the require statement for these checks, which is good practice.


Fund distribution:

If the word is revealed, the non-caller wins the entire bet amount.
If the word is not revealed, both players are refunded their bet amounts.


Potential issues:

The contract doesn't check if it has sufficient balance to make the transfers.
There's no mechanism to handle failed transfers.
The contract doesn't emit events for important state changes.


Improvements:

Use the "checks-effects-interactions" pattern to prevent reentrancy attacks.
Implement a withdrawal pattern instead of direct transfers for better security.
Add events to log important actions like session closures and fund transfers.
Include more detailed error messages in require statements.


Gas optimization:

The code could be optimized to reduce gas costs, e.g., by using a single transfer for the winner instead of calculating and transferring separately.








Implemented a withdrawal pattern: Instead of directly transferring funds, we now use pendingWithdrawals to store owed amounts and a separate withdraw function for players to claim their funds.
Added events: SessionClosed and WithdrawalRequested to log important state changes.
Used custom errors: This provides more detailed error messages and can save gas compared to long string messages in require statements.
Simplified logic: Removed redundant checks and calculations.
Improved security: By separating the fund distribution logic from the actual transfer, we reduce the risk of reentrancy attacks.
Added a balance check: In the withdraw function, we check if the contract has sufficient balance before attempting a transfer.
Used call instead of transfer: This is more future-proof and allows for more gas to be used in the receiving contract if needed.
Gas optimization: Reduced the number of state changes and simplified calculations.
*/
