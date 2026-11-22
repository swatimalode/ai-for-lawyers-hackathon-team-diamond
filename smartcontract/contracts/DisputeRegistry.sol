// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./MasterRegistry.sol";

contract DisputeRegistry is MasterRegistry {
    bytes32 public constant RECORD_EXECUTOR_ROLE =
        keccak256("RECORD_EXECUTOR_ROLE");
    bytes32 public constant COURT_AUTHORITY_ROLE =
        keccak256("COURT_AUTHORITY_ROLE");

    address public immutable registryWallet;
    address public immutable courtAuthority;

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
        bytes32 courtOrderHash;
        uint256 resolvedAt;
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

    event DisputeResolvedByCourt(
        uint256 indexed disputeId,
        string indexed parcelId,
        bytes32 indexed courtOrderHash,
        address courtAuthority
    );

    constructor(address admin, address registryWallet_, address courtAuthority_)
        MasterRegistry(admin)
    {
        require(admin != address(0), "Invalid admin");
        require(registryWallet_ != address(0), "Invalid registry wallet");
        require(courtAuthority_ != address(0), "Invalid court authority");

        registryWallet = registryWallet_;
        courtAuthority = courtAuthority_;

        _grantRole(REGISTRY_WRITER_ROLE, registryWallet_);
        _grantRole(RECORD_EXECUTOR_ROLE, registryWallet_);
        _grantRole(COURT_AUTHORITY_ROLE, courtAuthority_);
    }

    modifier onlyRegistryWallet() {
        require(msg.sender == registryWallet, "Only multisig can call");
        _;
    }

    modifier onlyCourtAuthority() {
        require(msg.sender == courtAuthority, "Only court authority can call");
        _;
    }

    function registerDispute (
        string calldata parcelId,
        uint256 disputedArea,
        bytes32 complaintHash,
        bytes32 evidenceHash
    )
        external
        onlyRole(COURT_AUTHORITY_ROLE)
        onlyCourtAuthority
    {
        require(disputedArea > 0, "Disputed area required");
        require(complaintHash != bytes32(0), "Complaint hash required");
        require(evidenceHash != bytes32(0), "Evidence hash required");

        Parcel memory parcel = parcels[parcelId];

        require(bytes(parcel.parcelId).length > 0, "Parcel does not exist");
        require(
            parcel.status == ParcelStatus.ACTIVE,
            "Parcel is not active"
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
            courtOrderHash: bytes32(0),
            resolvedAt: 0,
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
        onlyRegistryWallet
    {
        Dispute storage dispute = disputes[disputeId];
        require(bytes(dispute.parcelId).length > 0, "Dispute does not exist");

        DisputeStatus oldStatus = dispute.status;
        require(oldStatus != newStatus, "Status is unchanged");
        require(
            (oldStatus == DisputeStatus.REGISTERED &&
                newStatus == DisputeStatus.UNDER_REVIEW) ||
                (oldStatus == DisputeStatus.RESOLVED &&
                    newStatus == DisputeStatus.CLOSED),
            "Status transition requires court resolution"
        );

        dispute.status = newStatus;

        emit DisputeStatusUpdated(disputeId, oldStatus, newStatus);
    }

    function resolveDisputeByCourt(
        uint256 disputeId,
        bytes32 courtOrderHash
    )
        external
        onlyRole(COURT_AUTHORITY_ROLE)
        onlyCourtAuthority
    {
        Dispute storage dispute = disputes[disputeId];

        require(bytes(dispute.parcelId).length > 0, "Dispute does not exist");
        require(courtOrderHash != bytes32(0), "Court order hash required");
        require(dispute.status != DisputeStatus.RESOLVED, "Dispute already resolved");
        require(dispute.status != DisputeStatus.CLOSED, "Dispute is closed");

        bool wasActive = dispute.status == DisputeStatus.REGISTERED ||
            dispute.status == DisputeStatus.UNDER_REVIEW;

        if (wasActive) {
            activeDisputedAreaByParcel[dispute.parcelId] -= dispute.disputedArea;
        }

        dispute.status = DisputeStatus.RESOLVED;
        dispute.courtOrderHash = courtOrderHash;
        dispute.resolvedAt = block.timestamp;

        emit DisputeResolvedByCourt(
            disputeId,
            dispute.parcelId,
            courtOrderHash,
            msg.sender
        );
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

    function _beforeParcelMutation(string memory parcelId)
        internal
        view
        override
    {
        require(msg.sender == registryWallet, "Only multisig can mutate parcels");
        require(
            activeDisputedAreaByParcel[parcelId] == 0,
            "Parcel has an unresolved dispute"
        );
    }
}