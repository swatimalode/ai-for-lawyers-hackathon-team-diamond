# AI for Lawyers — Team Diamond

A blockchain land-registry prototype for recording parcels, subdivisions, mergers, ownership transfers, invalidations, and land disputes.

## Smart Contract Architecture

The project uses two separate deployed contracts:

- **DisputeRegistry**: combined parcel registry and dispute registry. It inherits `MasterRegistry` and exposes parcel management plus dispute-management functions.
- **MultiSigWallet**: separate approval wallet that submits, confirms, executes, and cancels calls to privileged contracts.

### Access Control

- `DEFAULT_ADMIN_ROLE`: deployed to the initial administrator. It controls role administration.
- `REGISTRY_WRITER_ROLE`: grants permission for parcel registration and lifecycle changes.
- `RECORD_EXECUTOR_ROLE`: grants permission to register disputes and update dispute status.
- `COURT_AUTHORITY_ROLE`: assigned to the configured court address for dispute registration and resolution.

Parcel mutations and dispute status updates are restricted to the configured multisig wallet address. Dispute registration and court resolution are restricted to the configured court address. An active dispute blocks parcel mutations until the court resolves it.

## Parcel Lifecycle

- **Register**: create an active parcel with a sequential ID such as `Plot_MH_1`.
- **Subdivide**: split a parent parcel into multiple unique child parcel IDs.
- **Merge**: combine source parcels of the same owner and location into a new parcel.
- **Partial transfer**: transfer a portion of a parcel and create a new parcel ID for the transferred area.
- **Invalidate**: mark a parcel inactive and remove its remaining transferable area.
- **View**: retrieve parcel details. An unknown ID is represented as inactive by `getParcel`.

## Dispute Lifecycle

- `REGISTERED`
- `UNDER_REVIEW`
- `RESOLVED`
- `CLOSED`

A parcel can have multiple disputes. Each dispute stores a disputed-area amount, complaint hash, evidence hash, parcel ID, status, and creation time.

Active disputed areas are tracked separately and must not exceed the parcel's remaining area.

## Project Structure

```text
smartcontract/
├── contracts/
│   ├── DisputeRegistry.sol
│   ├── MasterRegistry.sol
│   └── MultiSigWallet.sol
├── ignition/modules/Registry.ts
├── test/
├── hardhat.config.ts
└── package.json
```

## Setup

Install dependencies:

```bash
cd smartcontract
npm install
```

Compile the contracts:

```bash
npx hardhat compile
```

Run tests:

```bash
npx hardhat test
```

## Local Deployment

Deploy the combined registry/dispute contract and the separate multisig wallet:

```bash
npx hardhat ignition deploy ignition/modules/Registry.ts --network hardhatMainnet
```

The module deploys:

- `DisputeRegistry`
- `MultiSigWallet`

It also grants `REGISTRY_WRITER_ROLE` and `RECORD_EXECUTOR_ROLE` to the multisig wallet.

## Sepolia Deployment

Configure the Sepolia credentials and prepare an Ignition parameter file containing the court authority address:

```bash
npx hardhat keystore set SEPOLIA_RPC_URL
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

`ignition/parameters/sepolia.json` should contain:

```json
{
  "RegistryModuleV4": {
    "courtAuthority": "0xCOURT_AUTHORITY_ADDRESS"
  }
}
```

Deploy:

```bash
npx hardhat ignition deploy ignition/modules/Registry.ts \
  --network sepolia \
  --parameters ignition/parameters/sepolia.json
```

`RegistryModuleV4` deploys new contracts. It does not modify the earlier Sepolia deployments.

Verify the deployed contracts:

```bash
npx hardhat keystore set ETHERSCAN_API_KEY

npx hardhat verify --network sepolia \
  0xC78D8E805Be4281af7bB5463Bd4e73C15936941B \
  0x9305596eD13B2A4C8Ff6f53A051F3d7c036dE844

npx hardhat verify --network sepolia \
  0xdffd6F017AeE1bd57253A3Ca4d7beb82D92D26b7 \
  '["0x9305596eD13B2A4C8Ff6f53A051F3d7c036dE844"]' \
  1
```

The owner array is written as JSON to prevent Sourcify constructor-argument parsing errors. Blockscout can return HTTP 429; retry later or verify through Etherscan after setting `ETHERSCAN_API_KEY`.

## Security Notes

- Keep `DEFAULT_ADMIN_ROLE` separate from operational writer and dispute roles.
- Use multiple trusted multisig owners for production deployment.
- Use legal document hashes to establish off-chain authority and evidence provenance.
- The contract can verify owner, location, and area state, but physical adjacency requires boundary or geometry data not currently stored on-chain.

Deploying [ RegistryModule ]

Batch #1
  Executed RegistryModule#DisputeRegistry
  Executed RegistryModule#MultiSigWallet

Batch #2
  Executed RegistryModule#GrantRecordExecutorRole
  Executed RegistryModule#GrantRegistryWriterRole

[ RegistryModule ] successfully deployed 🚀

Deployed Addresses

RegistryModule#DisputeRegistry - 0xC78D8E805Be4281af7bB5463Bd4e73C15936941B
RegistryModule#MultiSigWallet - 0xdffd6F017AeE1bd57253A3Ca4d7beb82D92D26b7