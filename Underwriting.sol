// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.18;
import "./Globals.sol";
import "./ContractRegistry.sol";
import "./Policy.sol";

contract PremiumPayment {
    ContractRegistry contractRegistry;
    Policy policyContract;

    constructor(address _contractregistryAddress) {
        contractRegistry = ContractRegistry(_contractregistryAddress);
        policyContract = Policy(contractRegistry.getContract(REGISTRY_KEY_POLICY));
    }

    function checkEligibility(uint256 _age, bool _sex) external pure returns(bool) {
        return (_age > 0 && (_sex || !_sex));
    }
}