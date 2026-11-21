import { expect } from "chai";
import { network } from "hardhat";
import { ethers as ethersLib } from "ethers";

const { ethers } = await network.create();

describe("Land registry and disputes", function () {
  it("registers a parcel and creates/updates a dispute", async function () {
    const [admin, other] = await ethers.getSigners();
    const registry = await ethers.deployContract("DisputeRegistry", [admin.address]);

    const writerRole = ethersLib.keccak256(
      ethersLib.toUtf8Bytes("REGISTRY_WRITER_ROLE")
    );
    const executorRole = await registry.RECORD_EXECUTOR_ROLE();

    await registry.grantRole(writerRole, admin.address);

    const ownerReference = ethersLib.keccak256(
      ethersLib.toUtf8Bytes("owner-a")
    );

    await registry.registerParcel(
      ownerReference,
      "Pune",
      "Haveli",
      "Baner",
      "10",
      "2",
      6n
    );

    const parcel = await registry.getParcel("Plot_MH_1");
    expect(parcel.parcelId).to.equal("Plot_MH_1");
    expect(parcel.ownerReference).to.equal(ownerReference);
    expect(parcel.area).to.equal(6n);
    expect(parcel.remainingArea).to.equal(6n);
    expect(parcel.status).to.equal(0n);

    await registry.registerDispute(
      "Plot_MH_1",
      2n,
      ethersLib.keccak256(ethersLib.toUtf8Bytes("complaint")),
      ethersLib.keccak256(ethersLib.toUtf8Bytes("evidence"))
    );

    expect(await registry.nextDisputeId()).to.equal(2n);
    expect(await registry.activeDisputedAreaByParcel("Plot_MH_1")).to.equal(2n);

    await registry.updateDisputeStatus(1n, 2n);
    expect(await registry.activeDisputedAreaByParcel("Plot_MH_1")).to.equal(0n);

    await registry.registerParcel(
      ownerReference,
      "Pune",
      "Haveli",
      "Baner",
      "11",
      "1",
      3n
    );
  });

  it("rejects a dispute for a nonexistent parcel", async function () {
    const [admin] = await ethers.getSigners();
    const registry = await ethers.deployContract("DisputeRegistry", [admin.address]);

    await expect(
      registry.registerDispute(
        "Plot_MH_999",
        1n,
        ethersLib.keccak256(ethersLib.toUtf8Bytes("complaint")),
        ethersLib.keccak256(ethersLib.toUtf8Bytes("evidence"))
      )
    ).to.be.revertedWith("Parcel does not exist");
  });

  it("deploys the multisig and submits a transaction", async function () {
    const [admin] = await ethers.getSigners();
    const wallet = await ethers.deployContract("MultiSigWallet", [[admin.address], 1]);

    expect(await wallet.requiredConfirmations()).to.equal(1n);
    expect(await wallet.isOwner(admin.address)).to.equal(true);

    const transactionId = await wallet.submitTransaction.staticCall(
      admin.address,
      0n,
      "0x"
    );
    await wallet.submitTransaction(admin.address, 0n, "0x");

    expect(transactionId).to.equal(0n);
  });
});
