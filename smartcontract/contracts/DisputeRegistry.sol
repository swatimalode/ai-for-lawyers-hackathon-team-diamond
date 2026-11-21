// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./MasterRegistry.sol";

contract DisputeRegistry is MasterRegistry {
    bytes32 public constant RECORD_EXECUTOR_ROLE =
        keccak256("RECORD_EXECUTOR_ROLE");

    enum DisputeStatus {
        REGISTERED,
        UNDER_REVIEW,
        RESOLVED,
        CLOSED
    }

    struct LandSnapshot {
        string parcelId;
        bytes32 ownerReference;
        bytes32 documentHash;
        uint256 area;
        uint256 remainingArea;
        uint8 parcelStatus;
        uint256 createdAt;
        uint256 snappedAt;
    }

    struct Dispute {
        uint256 disputeId;
        string parcelId;
        uint256 disputedArea;
        bytes32 complaintDocumentHash;
        bytes32 evidenceHash;
        DisputeStatus status;
        uint256 createdAt;
    }

    mapping(uint256 => Dispute) public disputes;
    mapping(string => uint256[]) public disputeIdsByParcel;
    mapping(string => uint256) public activeDisputedAreaByParcel;

    uint256 public nextDisputeId = 1;

    event DisputeRegistered(
        uint256 indexed disputeId,
        string indexed parcelId,
        bytes32 complaintDocumentHash,
        bytes32 evidenceHash
    );

    event DisputeStatusUpdated(
        uint256 indexed disputeId,
        DisputeStatus oldStatus,
        DisputeStatus newStatus
    );

    constructor(address admin) MasterRegistry(admin) {
        require(admin != address(0), "Invalid admin");

        _grantRole(RECORD_EXECUTOR_ROLE, admin);
    }

    function registerDispute(
        string calldata parcelId,
        uint256 disputedArea,
        bytes32 complaintHash,
        bytes32 evidenceHash
    )
        external
        onlyRole(RECORD_EXECUTOR_ROLE)
    {
        require(disputedArea > 0, "Disputed area required");
        require(complaintHash != bytes32(0), "Complaint hash required");
        require(evidenceHash != bytes32(0), "Evidence hash required");

        Parcel memory parcel = parcels[parcelId];

        require(bytes(parcel.parcelId).length > 0, "Parcel does not exist");
        require(
            parcel.status != ParcelStatus.INACTIVE,
            "Parcel is inactive"
        );
        require(disputedArea <= parcel.remainingArea, "Disputed area exceeds parcel area");
        uint256 activeArea = activeDisputedAreaByParcel[parcelId];
        require(
            activeArea + disputedArea <= parcel.remainingArea,
            "Active disputed area exceeds parcel area"
        );

        uint256 disputeId = nextDisputeId++;

        disputes[disputeId] = Dispute({
            disputeId: disputeId,
            parcelId: parcelId,
            disputedArea: disputedArea,
            complaintDocumentHash: complaintHash,
            evidenceHash: evidenceHash,
            status: DisputeStatus.REGISTERED,
            createdAt: block.timestamp
        });

        disputeIdsByParcel[parcelId].push(disputeId);
        activeDisputedAreaByParcel[parcelId] += disputedArea;

        emit DisputeRegistered(
            disputeId,
            parcelId,
            complaintHash,
            evidenceHash
        );
    }

    function updateDisputeStatus(
        uint256 disputeId,
        DisputeStatus newStatus
    )
        external
        onlyRole(RECORD_EXECUTOR_ROLE)
    {
        Dispute storage dispute = disputes[disputeId];
        require(bytes(dispute.parcelId).length > 0, "Dispute does not exist");

        DisputeStatus oldStatus = dispute.status;
        require(oldStatus != newStatus, "Status is unchanged");
        require(newStatus != DisputeStatus.REGISTERED, "Cannot reset status");

        bool wasActive = oldStatus == DisputeStatus.REGISTERED ||
            oldStatus == DisputeStatus.UNDER_REVIEW;
        bool isActive = newStatus == DisputeStatus.REGISTERED ||
            newStatus == DisputeStatus.UNDER_REVIEW;

        if (wasActive && !isActive) {
            activeDisputedAreaByParcel[dispute.parcelId] -= dispute.disputedArea;
        } else if (!wasActive && isActive) {
            Parcel memory parcel = parcels[dispute.parcelId];

            require(
                activeDisputedAreaByParcel[dispute.parcelId] +
                    dispute.disputedArea <= parcel.remainingArea,
                "Active disputed area exceeds parcel area"
            );

            activeDisputedAreaByParcel[dispute.parcelId] += dispute.disputedArea;
        }

        dispute.status = newStatus;

        emit DisputeStatusUpdated(disputeId, oldStatus, newStatus);
    }

    function getDispute(uint256 disputeId)
        external
        view
        returns (Dispute memory)
    {
        return disputes[disputeId];
    }

    function getDisputeIdsByParcel(string calldata parcelId)
        external
        view
        returns (uint256[] memory)
    {
        return disputeIdsByParcel[parcelId];
    }

    function getActiveDisputedAreaByParcel(string calldata parcelId)
        external
        view
        returns (uint256)
    {
        return activeDisputedAreaByParcel[parcelId];
    }
}