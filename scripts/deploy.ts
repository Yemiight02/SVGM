import { ethers, network } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  const [deployer] = await ethers.getSigners();
  const name = process.env.COLLECTION_NAME ?? "Pharos Genesis";
  const symbol = process.env.COLLECTION_SYMBOL ?? "PHG";

  console.log(`Deploying OnchainSVG to ${network.name} from ${deployer.address}`);

  const Factory = await ethers.getContractFactory("OnchainSVG");
  const c = await Factory.deploy(name, symbol, deployer.address);
  await c.waitForDeployment();
  const addr = await c.getAddress();
  console.log(`OnchainSVG deployed to: ${addr}`);

  const outDir = path.join(__dirname, "..", "deployments", network.name);
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(
    path.join(outDir, "OnchainSVG.json"),
    JSON.stringify(
      {
        network: network.name,
        chainId: (network.config.chainId ?? 0).toString(),
        address: addr,
        deployer: deployer.address,
        name,
        symbol,
        timestamp: new Date().toISOString(),
      },
      null,
      2,
    ),
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
