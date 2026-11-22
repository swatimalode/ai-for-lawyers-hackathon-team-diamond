import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("RegistryModuleV4", (m) => {
  const admin = m.getAccount(0);
  const courtAuthority = m.getParameter("courtAuthority");
  const multiSigWallet = m.contract("MultiSigWallet", [[admin,"0xbdbEfCa84352e02b431226ae5925b7A20f8C2195","0x793273ed7203391867902abb56a6A6C0B4574526"], 2]);
  const disputeRegistry = m.contract("DisputeRegistry", [
    admin,
    multiSigWallet,
    courtAuthority,
  ]);

  return { disputeRegistry, multiSigWallet };
});
