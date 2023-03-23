const sigUtils = require("@metamask/eth-sig-util");

function updateEncryptionPublicKey() {
  const encriptionPublicKey = sigUtils.getEncryptionPublicKey(process.env.PRIVATE_KEY);
  console.log(`Encryption public key: ${encriptionPublicKey}`);
  const fs = require("fs");
  fs.writeFileSync("encryption-public-key.txt", encriptionPublicKey);
}

async function deployContract(contractName, contractRegistryKey, contractRegistry) {
  // Deploy the contract and pass the ContractRegistry address to the constructor
  const Contract = await ethers.getContractFactory(contractName);
  const contract = await Contract.deploy(contractRegistry.address);

  console.log(`${contractName} deployed to address:`, contract.address);

  // Add the deployed contract to the ContractRegistry
  await contractRegistry.addContract(contractRegistryKey, contract.address);
  console.log(`${contractName} added to ContractRegistry`);

  return contract;
}

async function main() {
  updateEncryptionPublicKey();

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy the ContractRegistry contract
  const ContractRegistry = await ethers.getContractFactory("ContractRegistry");
  const contractRegistry = await ContractRegistry.deploy();

  console.log("ContractRegistry deployed to address:", contractRegistry.address);

  // Write the ContractRegistry address to a file
  const fs = require("fs");
  fs.writeFileSync("contract-registry-address.txt", contractRegistry.address);

  // Define an array of contract names to deploy
  const contractNames = ["Policy", "ClaimApplication"];
  const contractRegistryKeys = ["policy", "claimApplication"];

  // Deploy each contract and add it to the ContractRegistry
  for (let i = 0; i < contractNames.length; i++) {
    const contractName = contractNames[i];
    const contractRegistryKey = contractRegistryKeys[i];
    await deployContract(contractName, contractRegistryKey, contractRegistry);
  }

  console.log("All contracts deployed");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
