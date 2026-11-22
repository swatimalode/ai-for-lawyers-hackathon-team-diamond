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

## Verify on Sepolia

Set an Etherscan API key in Hardhat's keystore:

```bash
npx hardhat keystore set ETHERSCAN_API_KEY
```

Use a valid Etherscan API V2 key. `hardhat.config.ts` reads it from the keystore using `configVariable("ETHERSCAN_API_KEY")`.

Verify the V4 `DisputeRegistry` with its constructor arguments (`admin`, multisig address, court authority):

```bash
npx hardhat verify etherscan --network sepolia \
	0x9E88515Fe28a7b77E17c68458e57aEe50D6300AF \
	0x9305596eD13B2A4C8Ff6f53A051F3d7c036dE844 \
	0xf1D343Ac3fc48b0fE17e7500F2934EEE126f8A05 \
	0x9305596eD13B2A4C8Ff6f53A051F3d7c036dE844
```

Verify the V4 `MultiSigWallet`. The constructor-arguments module supplies the owners array and 2-of-3 threshold:

```bash
npx hardhat verify etherscan --network sepolia \
	--constructor-args-path ignition/parameters/verify-multisig.ts \
	0xf1D343Ac3fc48b0fE17e7500F2934EEE126f8A05
```

If an explorer reports HTTP 429, retry later. Etherscan verification requires a valid API key.

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
```

## Solidity Compiler

The project enables `viaIR` and optimizer settings to support the stack-heavy registry functions.

RegistryModuleV4#MultiSigWallet 0xf1D343Ac3fc48b0fE17e7500F2934EEE126f8A05
RegistryModuleV4#DisputeRegistry - 0x9E88515Fe28a7b77E17c68458e57aEe50D6300AF