const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SVGMinter", function () {
  const sampleSvg =
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" width="10" height="10">' +
    '<rect width="10" height="10" fill="#0D0D0D"/>' +
    "</svg>";

  it("deploys a collection and mints through it", async function () {
    const [deployer, user] = await ethers.getSigners();
    const Minter = await ethers.getContractFactory("SVGMinter");
    const minter = await Minter.deploy();
    await minter.waitForDeployment();

    const tx = await minter.createCollection("Hello", "HEO", deployer.address);
    const receipt = await tx.wait();
    const collectionAddr = await minter.collections
      ? await (await minter.collections(0)).collection
      : null;
    // Read from the emitted event for portability.
    const event = receipt.logs
      .map((l) => {
        try {
          return minter.interface.parseLog(l);
        } catch {
          return null;
        }
      })
      .find((p) => p && p.name === "CollectionCreated");
    expect(event, "CollectionCreated event should be present").to.not.equal(undefined);
    const collection = await ethers.getContractAt("OnchainSVG", event.args.collection);

    await minter.mintTo(collection.target, user.address, sampleSvg);
    expect(await collection.totalSupply()).to.equal(1);
    expect(await collection.ownerOf(1)).to.equal(user.address);
  });
});
