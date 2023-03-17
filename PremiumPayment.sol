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

    function makePayment() external payable {
        require(msg.value > 0, "Payment amount must be greater than zero");

        Policy.PolicyHolder memory _policyHolder = policyContract.getPolicyHolder(msg.sender);
        Policy.PolicyDetails memory _policyDetails = policyContract.getPolicyDetails(msg.sender);
        Policy.PolicyPayments memory _policyPayments = policyContract.getPolicyPayments(msg.sender);

        require(_policyHolder.policyNumber != 0,
            "Current user doesn't have a policy");
        require(block.timestamp <= _policyDetails.endDate, "Policy expired");
        require(block.timestamp <= _policyPayments.nextDeadline,
            "Pyment deadline has been missed. The policy is inactive");
        require(_policyPayments.nextDeadline < _policyDetails.endDate,
            "Payment deadline equals to or bigger than Policy end date.");
        require(msg.value == _policyDetails.premiumAmount, "Incorrect payment amount");

        // Update policy holder's premium payment status
        policyContract.updatePremiumPaymentStatus(msg.sender);

        // Transfer premium payment to insurer
        payable(address(policyContract)).transfer(msg.value);

    }
}