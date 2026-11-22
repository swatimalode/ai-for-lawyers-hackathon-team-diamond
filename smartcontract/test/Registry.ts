import { expect } from "chai";
import { ethers as ethersLib } from "ethers";
import { network } from "hardhat";

const { ethers } = await network.create();

async function executeWithMultisig(
  registry: any,
  wallet: any,
  owners: any[],
  functionName: string,
  args: unknown[]
) {
  const target = await registry.getAddress();
  const callData = registry.interface.encodeFunctionData(functionName, args);
  const transactionId = await wallet.connect(owners[0]).submitTransaction.staticCall(
    target,
    0n,
    callData
  );

  await wallet.connect(owners[0]).submitTransaction(target, 0n, callData);
  await wallet.connect(owners[0]).confirmTransaction(transactionId);
  await wallet.connect(owners[1]).confirmTransaction(transactionId);
  await wallet.connect(owners[2]).executeTransaction(transactionId);

  return transactionId;
}

describe("Court and multisig registry workflow", function () {
  it("requires court dispute actions and multisig parcel changes", async function () {
    const [admin, court, ownerOne, ownerTwo, ownerThree, outsider] =
      await ethers.getSigners();
    const wallet = await ethers.deployContract(
      "MultiSigWallet",
      [[ownerOne.address, ownerTwo.address, ownerThree.address], 2]
    );
    const walletAddress = await wallet.getAddress();
    const registry = await ethers.deployContract("DisputeRegistry", [
      admin.address,
      walletAddress,
      court.address,
    ]);
    const writerRole = await registry.REGISTRY_WRITER_ROLE();
    const executorRole = await registry.RECORD_EXECUTOR_ROLE();
    const courtRole = await registry.COURT_AUTHORITY_ROLE();

    const ownerReference = ethersLib.keccak256(
      ethersLib.toUtf8Bytes("land-owner")
    );

    await executeWithMultisig(registry, wallet, [ownerOne, ownerTwo, ownerThree], "registerParcel", [
      ownerReference,
      "Pune",
      "Haveli",
      "Baner",
      "10",
      "1",
      6n,
    ]);

    const complaintHash = ethersLib.keccak256(
      ethersLib.toUtf8Bytes("complaint-document")
    );
    const evidenceHash = ethersLib.keccak256(
      ethersLib.toUtf8Bytes("evidence-document")
    );

    await expect(
      registry.connect(admin).registerDispute(
        "Plot_MH_1",
        2n,
        complaintHash,
        evidenceHash
      )
    ).revert(ethers);

    await registry.connect(court).registerDispute(
      "Plot_MH_1",
      2n,
      complaintHash,
      evidenceHash
    );

    await registry.grantRole(executorRole, admin.address);
    await expect(
      registry.connect(admin).updateDisputeStatus(1n, 1)
    ).revertedWith("Only multisig can call");

    await executeWithMultisig(registry, wallet, [ownerOne, ownerTwo, ownerThree], "updateDisputeStatus", [
      1n,
      1,
    ]);

    const courtOrderHash = ethersLib.keccak256(
      ethersLib.toUtf8Bytes("court-order")
    );

    await registry.grantRole(courtRole, outsider.address);
    await expect(
      registry.connect(outsider).resolveDisputeByCourt(1n, courtOrderHash)
    ).revertedWith("Only court authority can call");

    await registry.connect(court).resolveDisputeByCourt(1n, courtOrderHash);

    const dispute = await registry.getDispute(1n);
    expect(dispute.status).to.equal(2n);
    expect(dispute.courtOrderHash).to.equal(courtOrderHash);
    expect(await registry.activeDisputedAreaByParcel("Plot_MH_1")).to.equal(0n);

    await registry.grantRole(writerRole, admin.address);
    await expect(
      registry.connect(admin).transferOwnership(
        "Plot_MH_1",
        ethersLib.keccak256(ethersLib.toUtf8Bytes("admin-owner")),
        1n,
        ethersLib.keccak256(ethersLib.toUtf8Bytes("admin-transfer-document"))
      )
    ).revertedWith("Only multisig can mutate parcels");

    const newOwnerReference = ethersLib.keccak256(
      ethersLib.toUtf8Bytes("new-land-owner")
    );
    const transferDocumentHash = ethersLib.keccak256(
      ethersLib.toUtf8Bytes("transfer-document")
    );

    await executeWithMultisig(registry, wallet, [ownerOne, ownerTwo, ownerThree], "transferOwnership", [
      "Plot_MH_1",
      newOwnerReference,
      2n,
      transferDocumentHash,
    ]);

    const transferredParcel = await registry.getParcel("Plot_MH_2");
    expect(transferredParcel.ownerReference).to.equal(newOwnerReference);
    expect(transferredParcel.area).to.equal(2n);
    expect((await registry.getParcel("Plot_MH_1")).remainingArea).to.equal(4n);
  });

  it("rejects disputes for nonexistent parcels", async function () {
    const [admin, court] = await ethers.getSigners();
    const registry = await ethers.deployContract("DisputeRegistry", [
      admin.address,
      admin.address,
      court.address,
    ]);

    await expect(
      registry.connect(court).registerDispute(
        "Plot_MH_999",
        1n,
        ethersLib.keccak256(ethersLib.toUtf8Bytes("complaint")),
        ethersLib.keccak256(ethersLib.toUtf8Bytes("evidence"))
      )
    ).revertedWith("Parcel does not exist");
  });

  it("blocks registry mutations while a dispute is unresolved", async function () {
    const [admin, court, ownerOne, ownerTwo, ownerThree] = await ethers.getSigners();
    const wallet = await ethers.deployContract(
      "MultiSigWallet",
      [[ownerOne.address, ownerTwo.address, ownerThree.address], 2]
    );
    const registry = await ethers.deployContract("DisputeRegistry", [
      admin.address,
      await wallet.getAddress(),
      court.address,
    ]);

    const ownerReference = ethersLib.keccak256(ethersLib.toUtf8Bytes("owner"));
    await executeWithMultisig(registry, wallet, [ownerOne, ownerTwo, ownerThree], "registerParcel", [
      ownerReference,
      "Pune",
      "Haveli",
      "Baner",
      "10",
      "1",
      6n,
    ]);

    await registry.connect(court).registerDispute(
      "Plot_MH_1",
      2n,
      ethersLib.keccak256(ethersLib.toUtf8Bytes("complaint")),
      ethersLib.keccak256(ethersLib.toUtf8Bytes("evidence"))
    );

    const transferData = registry.interface.encodeFunctionData("transferOwnership", [
      "Plot_MH_1",
      ethersLib.keccak256(ethersLib.toUtf8Bytes("other-owner")),
      1n,
      ethersLib.keccak256(ethersLib.toUtf8Bytes("transfer-document")),
    ]);
    const target = await registry.getAddress();
    const transactionId = await wallet.connect(ownerOne).submitTransaction.staticCall(
      target,
      0n,
      transferData
    );

    await wallet.connect(ownerOne).submitTransaction(target, 0n, transferData);
    await wallet.connect(ownerOne).confirmTransaction(transactionId);
    await wallet.connect(ownerTwo).confirmTransaction(transactionId);

    await expect(
      wallet.connect(ownerThree).executeTransaction(transactionId)
    ).revertedWith("Transaction execution failed");
  });
});