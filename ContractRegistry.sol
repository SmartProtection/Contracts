// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.18;
import "@openzeppelin/contracts/access/Ownable.sol";

contract ContractRegistry is Ownable {
    mapping(string => address) private contractAddresses;
    string[] private contractNames;

    function addContract(string memory name, address contractAddress) external onlyOwner {
        contractAddresses[name] = contractAddress;
        contractNames.push(name);
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
