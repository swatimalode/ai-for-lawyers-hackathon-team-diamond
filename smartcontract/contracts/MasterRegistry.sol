// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MasterRegistry is AccessControl {

    // Role allowed to register or modify parcel structure
    bytes32 public constant REGISTRY_WRITER_ROLE =
        keccak256("REGISTRY_WRITER_ROLE");

    enum ParcelStatus {
        ACTIVE,
        SUBDIVIDED,
        MERGED,
        INACTIVE
    }

    struct sourceParcel {
        uint256[] parentParcelIds;
        string[] sourceParcelIds;
        uint256[] areaTaken;
        bytes32[] ownerReferences;
    }

    struct Parcel {
        string parcelId;
        bytes32 ownerReference;

        uint256 parentParcelId;
        sourceParcel[] sourceParcelDetails;

        string district;
        string taluka;
        string village;

        string surveyNumber;
        string hissaNumber;

        uint256 area;
        uint256 remainingArea;
        ParcelStatus status;
        bytes32 documentHash;

        uint256 createdAt;
    }

    mapping(string => Parcel) public parcels;

    uint256 public nextParcelId = 1;

    event ParcelRegistered(
        string indexed parcelId,
        bytes32 indexed ownerReference,
        address indexed registeredBy,
        uint256 area
    );

    event ParcelSubdivided(
        uint256 indexed parentParcelId,
        string parentParcelKey,
        address indexed subdividedBy,
        string[] childParcelIds,
        uint256 childCount
    );

    event ParcelsMerged(
        string indexed newParcelId,
        string[] sourceParcelIds,
        bytes32 ownerReference,
        uint256 totalArea,
        address indexed mergedBy
    );

    event ParcelOwnershipTransferred(
        string indexed parcelId,
        bytes32 indexed previousOwnerReference,
        bytes32 indexed newOwnerReference,
        address transferredBy
    );

    event ParcelInvalidated(
        string indexed parcelId,
        address indexed invalidatedBy,
        uint256 invalidatedAt
    );

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // Register an original land parcel
    function registerParcel(
        bytes32 ownerReference,
        string calldata district,
        string calldata taluka,
        string calldata village,
        string calldata surveyNumber,
        string calldata hissaNumber,
        uint256 area
    )
        external
        onlyRole(REGISTRY_WRITER_ROLE)
    {
        require(
            ownerReference != bytes32(0) &&
                bytes(district).length > 0 &&
                bytes(taluka).length > 0 &&
                bytes(village).length > 0 &&
                bytes(surveyNumber).length > 0 &&
                bytes(hissaNumber).length > 0 &&
                area > 0,
            "Invalid parcel data"
        );

        string memory parcelId = string.concat(
            "Plot_MH_",
            Strings.toString(nextParcelId)
        );

        Parcel storage parcel = parcels[parcelId];
        parcel.parcelId = parcelId;
        parcel.ownerReference  = ownerReference;
        parcel.district = district;
        parcel.taluka = taluka;
        parcel.village = village;
        parcel.surveyNumber = surveyNumber;
        parcel.hissaNumber = hissaNumber;
        parcel.area = area;
        parcel.remainingArea = area;
        parcel.status = ParcelStatus.ACTIVE;
        parcel.createdAt = block.timestamp;

        nextParcelId++;

        emit ParcelRegistered(
            parcelId,
            ownerReference,
            msg.sender,
            area
        );
    }

    // Subdivide an existing parcel
    function subdivideParcel(
        uint256 parentParcelId,
        Parcel[] memory children
    )
        external
        onlyRole(REGISTRY_WRITER_ROLE)
    {
        string memory parentKey = string.concat(
            "Plot_MH_",
            Strings.toString(parentParcelId)
        );

        Parcel storage parent = parcels[parentKey];
        require(bytes(parent.parcelId).length > 0, "Parent parcel does not exist");
        require(parent.status == ParcelStatus.ACTIVE, "Parent parcel is not active");
        require(children.length > 1, "At least two children are required");

        uint256 childAreaTotal;

        for (uint256 i = 0; i < children.length; i++) {
            require(children[i].ownerReference != bytes32(0), "Invalid owner reference");
            require(bytes(children[i].district).length > 0, "District is required");
            require(bytes(children[i].taluka).length > 0, "Taluka is required");
            require(bytes(children[i].village).length > 0, "Village is required");
            require(bytes(children[i].surveyNumber).length > 0, "Survey number is required");
            require(bytes(children[i].hissaNumber).length > 0, "Hissa number is required");
            require(children[i].area > 0, "Child area must be greater than zero");

            childAreaTotal += children[i].area;
        }

        require(childAreaTotal == parent.area, "Child areas must equal parent area");

        string[] memory childParcelIds = new string[](children.length);

        for (uint256 i = 0; i < children.length; i++) {
            string memory childId = string.concat(
                "Plot_MH_",
                Strings.toString(nextParcelId)
            );

            Parcel storage child = parcels[childId];
            child.parcelId = childId;
            child.ownerReference = children[i].ownerReference;
            child.parentParcelId = parentParcelId;
            child.district = children[i].district;
            child.taluka = children[i].taluka;
            child.village = children[i].village;
            child.surveyNumber = children[i].surveyNumber;
            child.hissaNumber = children[i].hissaNumber;
            child.area = children[i].area;
            child.remainingArea = children[i].area;
            child.status = ParcelStatus.ACTIVE;
            child.documentHash = children[i].documentHash;
            child.createdAt = block.timestamp;

            sourceParcel memory source;
            source.parentParcelIds = new uint256[](1);
            source.parentParcelIds[0] = parentParcelId;
            source.areaTaken = new uint256[](1);
            source.areaTaken[0] = children[i].area;
            source.ownerReferences = new bytes32[](1);
            source.ownerReferences[0] = children[i].ownerReference;
            source.sourceParcelIds = new string[](1);
            source.sourceParcelIds[0] = parentKey;

            child.sourceParcelDetails.push(source);
            childParcelIds[i] = childId;
            nextParcelId++;
        }

        parent.status = ParcelStatus.SUBDIVIDED;
        parent.remainingArea = 0;

        emit ParcelSubdivided(
            parentParcelId,
            parentKey,
            msg.sender,
            childParcelIds,
            children.length
        );
    }

    function mergeParcels(
        string[] calldata sourceParcelIds,
        uint256[] calldata areaTaken,
        string calldata newSurveyNumber,
        string calldata newHissaNumber,
        bytes32 documentHash
    )
        external
        onlyRole(REGISTRY_WRITER_ROLE)
    {
        bytes32 mergedOwner;
        uint256 totalArea;

        (mergedOwner, totalArea) = _validateMergeSources(sourceParcelIds, areaTaken);

        string memory newParcelId = _createMergedParcel(
            sourceParcelIds,
            areaTaken,
            mergedOwner,
            newSurveyNumber,
            newHissaNumber,
            documentHash,
            totalArea
        );

        emit ParcelsMerged(
            newParcelId,
            sourceParcelIds,
            mergedOwner,
            totalArea,
            msg.sender
        );
    }

    function _createMergedParcel(
        string[] calldata sourceParcelIds,
        uint256[] calldata areaTaken,
        bytes32 ownerReference,
        string calldata newSurveyNumber,
        string calldata newHissaNumber,
        bytes32 documentHash,
        uint256 totalArea
    )
        internal
        returns (string memory newParcelId)
    {
        require(bytes(newSurveyNumber).length > 0, "Survey number is required");
        require(bytes(newHissaNumber).length > 0, "Hissa number is required");
        require(documentHash != bytes32(0), "Document hash is required");

        newParcelId = string.concat(
            "Plot_MH_",
            Strings.toString(nextParcelId)
        );

        Parcel storage newParcel = parcels[newParcelId];
        Parcel storage firstSource = parcels[sourceParcelIds[0]];

        newParcel.parcelId = newParcelId;
        newParcel.ownerReference = ownerReference;
        newParcel.parentParcelId = 0;
        newParcel.district = firstSource.district;
        newParcel.taluka = firstSource.taluka;
        newParcel.village = firstSource.village;
        newParcel.surveyNumber = newSurveyNumber;
        newParcel.hissaNumber = newHissaNumber;
        newParcel.area = totalArea;
        newParcel.remainingArea = totalArea;
        newParcel.status = ParcelStatus.ACTIVE;
        newParcel.documentHash = documentHash;
        newParcel.createdAt = block.timestamp;

        for (uint256 i = 0; i < sourceParcelIds.length; i++) {
            string memory sourceId = sourceParcelIds[i];

            sourceParcel memory source;
            source.parentParcelIds = new uint256[](1);
            source.parentParcelIds[0] = nextParcelId;
            source.areaTaken = new uint256[](1);
            source.areaTaken[0] = areaTaken[i];
            source.ownerReferences = new bytes32[](1);
            source.ownerReferences[0] = ownerReference;
            source.sourceParcelIds = new string[](1);
            source.sourceParcelIds[0] = sourceId;

            newParcel.sourceParcelDetails.push(source);
            parcels[sourceId].remainingArea -= areaTaken[i];

            if (parcels[sourceId].remainingArea == 0) {
                parcels[sourceId].status = ParcelStatus.MERGED;
            }
        }

        nextParcelId++;
    }

    function transferOwnership(
        string calldata parcelId,
        bytes32 newOwnerReference,
        uint256 transferArea,
        bytes32 documentHash
    )
        external
        onlyRole(REGISTRY_WRITER_ROLE)
    {
        Parcel storage source = parcels[parcelId];

        require(bytes(source.parcelId).length > 0, "Parcel does not exist");
        require(source.status == ParcelStatus.ACTIVE, "Parcel is not active");
        require(source.remainingArea > 0, "Parcel has no remaining area");
        require(transferArea > 0, "Transfer area must be greater than zero");
        require(transferArea <= source.remainingArea, "Transfer area exceeds remaining area");
        require(newOwnerReference != bytes32(0), "Invalid owner reference");
        require(source.ownerReference != newOwnerReference, "Owner is unchanged");
        require(documentHash != bytes32(0), "Document hash is required");

        bytes32 previousOwnerReference = source.ownerReference;

        string memory transferredParcelId = string.concat(
            "Plot_MH_",
            Strings.toString(nextParcelId)
        );

        Parcel storage transferredParcel = parcels[transferredParcelId];
        transferredParcel.parcelId = transferredParcelId;
        transferredParcel.ownerReference = newOwnerReference;
        transferredParcel.parentParcelId = 0;
        transferredParcel.district = source.district;
        transferredParcel.taluka = source.taluka;
        transferredParcel.village = source.village;
        transferredParcel.surveyNumber = source.surveyNumber;
        transferredParcel.hissaNumber = source.hissaNumber;
        transferredParcel.area = transferArea;
        transferredParcel.remainingArea = transferArea;
        transferredParcel.status = ParcelStatus.ACTIVE;
        transferredParcel.documentHash = documentHash;
        transferredParcel.createdAt = block.timestamp;

        sourceParcel memory sourceDetails;
        sourceDetails.sourceParcelIds = new string[](1);
        sourceDetails.sourceParcelIds[0] = parcelId;
        sourceDetails.areaTaken = new uint256[](1);
        sourceDetails.areaTaken[0] = transferArea;
        sourceDetails.ownerReferences = new bytes32[](1);
        sourceDetails.ownerReferences[0] = previousOwnerReference;

        transferredParcel.sourceParcelDetails.push(sourceDetails);

        source.remainingArea -= transferArea;
        nextParcelId++;

        if (source.remainingArea == 0) {
            source.status = ParcelStatus.MERGED;
        }

        emit ParcelOwnershipTransferred(
            parcelId,
            previousOwnerReference,
            newOwnerReference,
            msg.sender
        );
    }

    function invalidateParcel(string calldata parcelId)
        external
        onlyRole(REGISTRY_WRITER_ROLE)
    {
        Parcel storage parcel = parcels[parcelId];

        require(bytes(parcel.parcelId).length > 0, "Parcel does not exist");
        require(parcel.status != ParcelStatus.INACTIVE, "Parcel is already inactive");

        parcel.status = ParcelStatus.INACTIVE;
        parcel.remainingArea = 0;

        emit ParcelInvalidated(parcelId, msg.sender, block.timestamp);
    }

    function getParcel(string calldata parcelId)
        external
        view
        returns (Parcel memory)
    {
        Parcel memory parcel = parcels[parcelId];

        if (bytes(parcel.parcelId).length == 0) {
            parcel.parcelId = parcelId;
            parcel.status = ParcelStatus.INACTIVE;
        }

        return parcel;
    }

    function _validateMergeSources(
        string[] calldata sourceParcelIds,
        uint256[] calldata areaTaken
    )
        internal
        view
        returns (bytes32 ownerReference, uint256 totalArea)
    {
        require(sourceParcelIds.length >= 2, "Minimum two parcels required");
        require(sourceParcelIds.length == areaTaken.length, "Area data mismatch");

        bytes32 firstDistrict;
        bytes32 firstTaluka;
        bytes32 firstVillage;

        for (uint256 i = 0; i < sourceParcelIds.length; i++) {
            string memory sourceId = sourceParcelIds[i];
            Parcel storage source = parcels[sourceId];

            require(bytes(source.parcelId).length > 0, "Parcel does not exist");
            require(source.status == ParcelStatus.ACTIVE, "Parcel not active");
            require(areaTaken[i] > 0, "Invalid area");
            require(source.remainingArea >= areaTaken[i], "Insufficient remaining area");

            if (i == 0) {
                ownerReference = source.ownerReference;
                firstDistrict = keccak256(bytes(source.district));
                firstTaluka = keccak256(bytes(source.taluka));
                firstVillage = keccak256(bytes(source.village));
            } else {
                require(source.ownerReference == ownerReference, "Owners must match");
                require(
                    keccak256(bytes(source.district)) == firstDistrict &&
                    keccak256(bytes(source.taluka)) == firstTaluka &&
                    keccak256(bytes(source.village)) == firstVillage,
                    "Parcels must be in the same location"
                );

                for (uint256 j = 0; j < i; j++) {
                    require(
                        keccak256(bytes(sourceParcelIds[j])) !=
                            keccak256(bytes(sourceId)),
                        "Duplicate source parcel"
                    );
                }
            }

            totalArea += areaTaken[i];
        }
    }
}