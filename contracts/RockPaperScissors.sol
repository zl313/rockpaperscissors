// SPDX-License-Identifier: MIT
// compiler version must be greater than or equal to 0.8.13 and less than 0.9.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";

contract RockPaperScissors {
    struct Record {
        address firstPlayer;
        address secondPlayer;
        bytes32 firstHash;
        bytes32 secondHash;
        uint firstChoice;
        uint secondChoice;
        uint amount;
        uint progress;
    }

    mapping (address => uint) public balances;
    mapping (address => uint) public pendingBalances;
    mapping (address => Record) public records;

    function register() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        require(balances[msg.sender] > 0, "Non-positive amount");
        payable(msg.sender).transfer(balances[msg.sender]);
        balances[msg.sender] = 0;
    }

    function firstPlay(address secondPlayer, bytes32 hash, uint amount) external {
        require(amount > 0, "Non-positive amount");
        require(msg.sender != secondPlayer, "Self-playing not allowed");
        require(amount * 1 wei <= balances[msg.sender], "Insufficient funds");
        require(records[msg.sender].progress == 0, "There exists a record");

        balances[msg.sender] -= amount * 1 wei;
        pendingBalances[msg.sender] += amount * 1 wei;

        records[msg.sender] = Record(
            {
                firstPlayer : msg.sender,
                secondPlayer : secondPlayer,
                firstHash : hash,
                secondHash : 0,
                firstChoice : 0,
                secondChoice : 0,
                amount : amount * 1 wei,
                progress : 1
            });
    }

    function secondPlay(address firstPlayer, bytes32 hash) external {
        require(msg.sender == records[firstPlayer].secondPlayer, "Invalid second player");
        require(records[firstPlayer].progress == 1, "Invalid record");
        require(records[firstPlayer].amount <= balances[msg.sender], "Insufficient funds");

        balances[msg.sender] -= records[firstPlayer].amount;
        pendingBalances[msg.sender] += records[firstPlayer].amount;

        records[firstPlayer].secondHash = hash;
        records[firstPlayer].progress = 2;
    }

    function settle(address firstPlayer, uint choice, string memory salt) external {
        require(choice >= 1 && choice <= 3, "Invalid choice");
        require(records[firstPlayer].progress == 2 || records[firstPlayer].progress == 3, "Invalid record");
        require(records[firstPlayer].secondHash != 0, "Incomplete record");

        if (msg.sender == firstPlayer) {
            require(records[firstPlayer].firstChoice == 0, "Already settled for the first player");
            require(computeHash(choice, salt) == records[firstPlayer].firstHash, "Incorrect hash from choice and salt");
            records[firstPlayer].firstChoice = choice;
        } else {
            require(records[firstPlayer].secondChoice == 0, "Already settled for this current player");
            require(computeHash(choice, salt) == records[firstPlayer].secondHash, "Incorrect hash from choice and salt");
            records[firstPlayer].secondChoice = choice;
        }
        records[firstPlayer].progress += 1;
        if (records[firstPlayer].progress == 4) {
            // Settle this game
            pendingBalances[records[firstPlayer].firstPlayer] -= records[firstPlayer].amount;
            pendingBalances[records[firstPlayer].secondPlayer] -= records[firstPlayer].amount;
            if (records[firstPlayer].firstChoice == records[firstPlayer].secondChoice) {
                // Draw
                balances[records[firstPlayer].firstPlayer] += records[firstPlayer].amount;
                balances[records[firstPlayer].secondPlayer] += records[firstPlayer].amount;
            } else if (
                    (records[firstPlayer].firstChoice > records[firstPlayer].secondChoice
                    && records[firstPlayer].firstChoice - records[firstPlayer].secondChoice == 1)
                    || records[firstPlayer].secondChoice - records[firstPlayer].firstChoice == 2
                ) {
                // First player wins
                // 95% of the amount goes to the winning player, and the rest is owned by the contract creator
                balances[records[firstPlayer].firstPlayer] += records[firstPlayer].amount * 39 / 20;
            } else {
                // Second player wins
                // 95% of the amount goes to the winning player, and the rest is owned by the contract creator
                balances[records[firstPlayer].secondPlayer] += records[firstPlayer].amount * 39 / 20;
            }
            records[firstPlayer].progress = 0;
        }
    }

    function computeHash(uint choice, string memory salt) internal pure returns(bytes32) {
        return sha256(bytes(string.concat(Strings.toString(choice), salt)));
    }
}
