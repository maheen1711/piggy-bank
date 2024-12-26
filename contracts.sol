// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PiggyBank
 * @dev A smart contract that allows users to lock funds for a specified period
 */
contract PiggyBank {
    // Struct to store deposit information
    struct Deposit {
        uint256 amount;         // Amount deposited
        uint256 unlockTime;     // Time when funds can be withdrawn
        bool withdrawn;         // Flag to track if funds have been withdrawn
    }

    // Mapping to store deposits for each user
    mapping(address => Deposit[]) public userDeposits;

    // Events to log key actions
    event FundsDeposited(address indexed user, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 amount);

    /**
     * @dev Deposit funds with a specified lock period
     * @param _lockPeriod Duration in seconds for which funds will be locked
     */
    function deposit(uint256 _lockPeriod) external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(_lockPeriod > 0, "Lock period must be greater than 0");

        userDeposits[msg.sender].push(Deposit({
            amount: msg.value,
            unlockTime: block.timestamp + _lockPeriod,
            withdrawn: false
        }));

        emit FundsDeposited(msg.sender, msg.value, block.timestamp + _lockPeriod);
    }

    /**
     * @dev Withdraw funds after the lock period has ended
     * @param _depositIndex Index of the specific deposit to withdraw
     */
    function withdraw(uint256 _depositIndex) external {
        require(_depositIndex < userDeposits[msg.sender].length, "Invalid deposit index");
        
        Deposit storage depositToWithdraw = userDeposits[msg.sender][_depositIndex];
        
        require(block.timestamp >= depositToWithdraw.unlockTime, "Funds are still locked");
        require(!depositToWithdraw.withdrawn, "Funds already withdrawn");

        uint256 amount = depositToWithdraw.amount;
        
        // Mark as withdrawn before sending to prevent reentrancy
        depositToWithdraw.withdrawn = true;

        // Send funds back to the user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Emergency withdrawal with a penalty (50% of the deposit)
     * @param _depositIndex Index of the specific deposit to withdraw early
     */
    function emergencyWithdraw(uint256 _depositIndex) external {
        require(_depositIndex < userDeposits[msg.sender].length, "Invalid deposit index");
        
        Deposit storage depositToWithdraw = userDeposits[msg.sender][_depositIndex];
        
        require(!depositToWithdraw.withdrawn, "Funds already withdrawn");
        require(block.timestamp < depositToWithdraw.unlockTime, "Use regular withdraw");

        uint256 penaltyAmount = depositToWithdraw.amount / 2;
        uint256 withdrawAmount = depositToWithdraw.amount - penaltyAmount;

        // Mark as withdrawn before sending to prevent reentrancy
        depositToWithdraw.withdrawn = true;

        // Send funds back to the user (with penalty)
        (bool success, ) = msg.sender.call{value: withdrawAmount}("");
        require(success, "Transfer failed");

        emit EmergencyWithdrawal(msg.sender, withdrawAmount);
    }

    /**
     * @dev Get all deposits for the caller
     * @return Array of deposits
     */
    function getDeposits() external view returns (Deposit[] memory) {
        return userDeposits[msg.sender];
    }

    /**
     * @dev Get the total number of deposits for the caller
     * @return Number of deposits
     */
    function getDepositCount() external view returns (uint256) {
        return userDeposits[msg.sender].length;
    }
}