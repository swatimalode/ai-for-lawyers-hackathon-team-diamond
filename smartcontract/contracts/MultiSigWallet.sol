// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MultiSigWallet is ReentrancyGuard {
    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        bool executed;
        bool cancelled;
        uint256 confirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredConfirmations;

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    uint256 public nextTransactionId;

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequiredConfirmationsChanged(uint256 requiredConfirmations);
    event TransactionSubmitted(
        uint256 indexed transactionId,
        address indexed submitter,
        address indexed target,
        uint256 value,
        bytes data
    );
    event TransactionConfirmed(
        uint256 indexed transactionId,
        address indexed owner
    );
    event ConfirmationRevoked(
        uint256 indexed transactionId,
        address indexed owner
    );
    event TransactionCancelled(uint256 indexed transactionId);
    event TransactionExecuted(
        uint256 indexed transactionId,
        address indexed executor,
        bytes result
    );

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet can execute");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(
            transactions[transactionId].target != address(0),
            "Transaction does not exist"
        );
        _;
    }

    modifier notExecutedOrCancelled(uint256 transactionId) {
        Transaction storage transaction = transactions[transactionId];
        require(!transaction.executed, "Transaction already executed");
        require(!transaction.cancelled, "Transaction cancelled");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredConfirmations > 0 &&
                _requiredConfirmations <= _owners.length,
            "Invalid confirmation count"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);

            emit OwnerAdded(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {}

    function submitTransaction(
        address target,
        uint256 value,
        bytes calldata data
    )
        external
        onlyOwner
        returns (uint256 transactionId)
    {
        require(target != address(0), "Invalid target");

        transactionId = nextTransactionId++;

        transactions[transactionId] = Transaction({
            target: target,
            value: value,
            data: data,
            executed: false,
            cancelled: false,
            confirmations: 0
        });

        emit TransactionSubmitted(
            transactionId,
            msg.sender,
            target,
            value,
            data
        );
    }

    function confirmTransaction(uint256 transactionId)
        external
        onlyOwner
        transactionExists(transactionId)
        notExecutedOrCancelled(transactionId)
    {
        require(!isConfirmed[transactionId][msg.sender], "Already confirmed");

        isConfirmed[transactionId][msg.sender] = true;
        transactions[transactionId].confirmations++;

        emit TransactionConfirmed(transactionId, msg.sender);
    }

    function revokeConfirmation(uint256 transactionId)
        external
        onlyOwner
        transactionExists(transactionId)
        notExecutedOrCancelled(transactionId)
    {
        require(isConfirmed[transactionId][msg.sender], "Not confirmed");

        isConfirmed[transactionId][msg.sender] = false;
        transactions[transactionId].confirmations--;

        emit ConfirmationRevoked(transactionId, msg.sender);
    }

    function executeTransaction(uint256 transactionId)
        external
        onlyOwner
        nonReentrant
        transactionExists(transactionId)
        notExecutedOrCancelled(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];

        require(
            transaction.confirmations >= requiredConfirmations,
            "Not enough confirmations"
        );
        require(address(this).balance >= transaction.value, "Insufficient balance");

        transaction.executed = true;

        (bool success, bytes memory result) = transaction.target.call{
            value: transaction.value
        }(transaction.data);

        require(success, "Transaction execution failed");

        emit TransactionExecuted(transactionId, msg.sender, result);
    }

    function cancelTransaction(uint256 transactionId)
        external
        onlyOwner
        transactionExists(transactionId)
        notExecutedOrCancelled(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];

        transaction.cancelled = true;

        emit TransactionCancelled(transactionId);
    }

    function addOwner(address owner)
        external
        onlyWallet
    {
        require(owner != address(0), "Invalid owner");
        require(!isOwner[owner], "Owner already exists");

        isOwner[owner] = true;
        owners.push(owner);

        emit OwnerAdded(owner);
    }

    function removeOwner(address owner)
        external
        onlyWallet
    {
        require(isOwner[owner], "Owner does not exist");
        require(owners.length > 1, "Cannot remove the last owner");

        isOwner[owner] = false;

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        require(
            requiredConfirmations <= owners.length,
            "Required confirmations exceed owners"
        );

        emit OwnerRemoved(owner);
    }

    function changeRequiredConfirmations(uint256 newRequiredConfirmations)
        external
        onlyWallet
    {
        require(newRequiredConfirmations > 0, "Confirmation count too low");
        require(
            newRequiredConfirmations <= owners.length,
            "Confirmation count exceeds owners"
        );

        requiredConfirmations = newRequiredConfirmations;

        emit RequiredConfirmationsChanged(newRequiredConfirmations);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 transactionId)
        external
        view
        returns (Transaction memory)
    {
        return transactions[transactionId];
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}