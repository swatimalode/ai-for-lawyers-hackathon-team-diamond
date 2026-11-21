import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

export default buildModule("RegistryModule", (m) => {
  const admin = m.getAccount(0);
  const disputeRegistry = m.contract("DisputeRegistry", [admin]);
  const multiSigWallet = m.contract("MultiSigWallet", [[admin], 1]);

  const registryWriterRole = ethers.keccak256(
    ethers.toUtf8Bytes("REGISTRY_WRITER_ROLE")
  );
  const recordExecutorRole = ethers.keccak256(
    ethers.toUtf8Bytes("RECORD_EXECUTOR_ROLE")
  );

  m.call(disputeRegistry, "grantRole", [
    registryWriterRole,
    multiSigWallet,
  ]);

  m.call(disputeRegistry, "grantRole", [
    recordExecutorRole,
    multiSigWallet,
  ]);

  return { disputeRegistry, multiSigWallet };
});
