// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.18;

import "./Globals.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ContractRegistry is Ownable {
    mapping(string => address) private contractAddresses;
    string[] private contractNames;

    function addPolicyContract(address _policyContractAddress) external onlyOwner {
        addContract(REGISTRY_KEY_POLICY, _policyContractAddress);
    }
    
    function addClaimApplicationContract(address _claimApplicationContractAddress) external onlyOwner {
        addContract(REGISTRY_KEY_CLAIM_APPLICATION, _claimApplicationContractAddress);
    }

    function addContract(string memory name, address contractAddress) public onlyOwner {
        if(contractAddresses[name] == address(0)) {
            contractNames.push(name);
        }
        contractAddresses[name] = contractAddress;
    }

    function getContract(string memory name) external view returns (address) {
        return contractAddresses[name];
    }

    function removeContract(string memory name) external onlyOwner {
        delete contractAddresses[name];
        for (uint256 i = 0; i < contractNames.length; i++) {
            if (keccak256(bytes(contractNames[i])) == keccak256(bytes(name))) {
                contractNames[i] = contractNames[contractNames.length - 1];
                contractNames.pop();
                break;
            }
        }
    }

    function getContractNames() external view returns (string[] memory) {
        return contractNames;
    }
}
