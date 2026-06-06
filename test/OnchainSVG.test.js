const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OnchainSVG", function () {
  const sampleSvg =
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" width="10" height="10">' +
    '<circle cx="5" cy="5" r="4" fill="#2F80ED"/>' +
    "</svg>";

  async function deploy() {
    const [owner, user] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("OnchainSVG");
    const c = await Factory.deploy("Test", "TST", owner.address);
    await c.waitForDeployment();
    return { c, owner, user };
  }

  it("mints and returns a data:application/json tokenURI", async function () {
    const { c, owner, user } = await deploy();
    const tx = await c.connect(owner).mint(user.address, sampleSvg);
    await tx.wait();
    expect(await c.totalSupply()).to.equal(1);

    const uri = await c.tokenURI(1);
    expect(uri.startsWith("data:application/json;base64,")).to.equal(true);

    const json = JSON.parse(Buffer.from(uri.split(",")[1], "base64").toString("utf-8"));
    expect(json.name).to.equal("Onchain SVG #1");
    expect(json.image.startsWith("data:image/svg+xml;base64,")).to.equal(true);
  });

  it("rejects empty SVG", async function () {
    const { c, owner, user } = await deploy();
    await expect(c.connect(owner).mint(user.address, "")).to.be.revertedWithCustomError(c, "EmptySVG");
  });

  it("rejects SVGs with <script>", async function () {
    const { c, owner, user } = await deploy();
    const evil = sampleSvg.replace("circle", 'script type="text/javascript"');
    await expect(c.connect(owner).mint(user.address, evil)).to.be.revertedWithCustomError(
      c,
      "ForbiddenSVGContent",
    );
  });

  it("rejects SVGs with javascript: URI", async function () {
    const { c, owner, user } = await deploy();
    const evil = sampleSvg.replace('fill="#2F80ED"', 'fill="javascript:alert(1)"');
    await expect(c.connect(owner).mint(user.address, evil)).to.be.revertedWithCustomError(
      c,
      "ForbiddenSVGContent",
    );
  });

  it("rejects oversize SVG", async function () {
    const { c, owner, user } = await deploy();
    const big = "a".repeat(24577);
    await expect(c.connect(owner).mint(user.address, big)).to.be.revertedWithCustomError(
      c,
      "SVGTooLarge",
    );
  });

  it("enforces onlyOwner on mint", async function () {
    const { c, user, owner } = await deploy();
    // the non-owner is `user`
    await expect(c.connect(user).mint(user.address, sampleSvg)).to.be.revertedWithCustomError(
      c,
      "OwnableUnauthorizedAccount",
    );
  });
});
