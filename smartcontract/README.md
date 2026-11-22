# Smart Contracts

Hardhat 3 project for the land registry, dispute registry, and multisig approval workflow.

## Contracts

### `DisputeRegistry.sol`

The combined registry contract inherits `MasterRegistry`.

It provides:

- Parcel registration and lifecycle operations.
- Dispute registration and status updates.
- One parcel-to-many dispute mappings.
- Active disputed-area tracking.
- Court-only dispute registration and resolution.
- Parcel changes blocked while the parcel has an active dispute.

### `MasterRegistry.sol`

Provides:

- Parcel registration.
- Subdivision and merger support.
- Partial ownership transfer.
- Parcel invalidation.
- Parcel lookup and status history.

### `MultiSigWallet.sol`

Provides separate approval for contract calls:

- Submit transactions.
- Confirm or revoke confirmations.
- Execute transactions after the confirmation threshold.
- Cancel transactions.

## Installation

```bash
npm install
npx hardhat compile
```

## Testing

Run the complete test suite:

```bash
npx hardhat test
```

## Deployment

Deploy locally or to Hardhat's configured local network:

```bash
npx hardhat ignition deploy ignition/modules/Registry.ts --network hardhatMainnet
```

The V4 module deploys `MultiSigWallet` and `DisputeRegistry`. The registry constructor binds parcel changes and dispute-status updates to that wallet address, and court registration/resolution to the required `courtAuthority` parameter.

Pass the court address through an Ignition parameters file:

```json
{
	"RegistryModuleV4": {
		"courtAuthority": "0xCOURT_AUTHORITY_ADDRESS"
	}
}
```

```bash
npx hardhat ignition deploy ignition/modules/Registry.ts \
	--network sepolia \
	--parameters ignition/parameters/sepolia.json
```

V4 creates new contracts; it does not change contracts from earlier deployments.

## Roles

- `DEFAULT_ADMIN_ROLE`: role administration.
- `REGISTRY_WRITER_ROLE`: parcel and ownership operations.
- `RECORD_EXECUTOR_ROLE`: dispute operations.

Create a multisig with more than one trusted owner for production rather than using a single-owner wallet.

## Configuration

For Sepolia:

```bash
npx hardhat keystore set SEPOLIA_RPC_URL
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
npx hardhat ignition deploy ignition/modules/Registry.ts --network sepolia
```

## Solidity Compiler

The project enables `viaIR` and optimizer settings to support the stack-heavy registry functions.
