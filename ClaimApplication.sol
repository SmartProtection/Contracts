// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.18;
import "./Globals.sol";
import "./ContractRegistry.sol";
import "./Policy.sol";

contract ClaimApplication {
    struct Claim {
        address policyHolder;
        uint256 amount;
        bool verified;
        bool paid;
    }
    
    ContractRegistry contractRegistry;
    Policy policyContract;
    address insurer;

    Claim[] public claims;

    mapping(address => uint256) indeces;

    event ClaimApplicationSubmitted(address _policyHolder, uint256 _policyNumber);
    event ClaimApplicationVerified(address _policyHolder, uint256 _policyNumber);
    event ClaimApplicationApproved(address _policyHolder, uint256 _policyNumber);
    event ClaimApplicationRejected(address _policyHolder, uint256 _policyNumber);

    modifier onlyInsurer() {
        require(msg.sender == insurer, "Only the insurer can verify claims");
        _;
    }

    constructor(address _contractregistryAddress) {
        contractRegistry = ContractRegistry(_contractregistryAddress);
        policyContract = Policy(contractRegistry.getContract(REGISTRY_KEY_POLICY));
        insurer = policyContract.insurer();
    }

    function submitClaim(uint256 _ClaimAmount) external payable {
        Policy.PolicyDetails memory _policyDetails = policyContract.getPolicyDetails(msg.sender);
        require(msg.value == _policyDetails.deductible,
            "Policyholder should pay deductible for applying");
        require(_ClaimAmount > 0, "Claim amount must be greater than zero");
        require(policyContract.isPolicyHolder(msg.sender),
            "Only policy holders can submit claims");
        require(policyContract.isPolicyDeadlineValid(msg.sender),
            "Pyment deadline has been missed. The policy is inactive");
        require(policyContract.isPolicyEndTimeValid(msg.sender), "Policy expired");
        require(indeces[msg.sender] == 0, "Policy holder has already applied for claim");

        // Create a new claim and add it to the list
        Claim memory newClaim = Claim({
            policyHolder: msg.sender,
            amount: _ClaimAmount,
            verified: false,
            paid: false
        });
        claims.push(newClaim);
        indeces[msg.sender] = claims.length;

        // Transfer deductible to Policy contract
        payable(address(policyContract)).transfer(msg.value);

        emit ClaimApplicationSubmitted(msg.sender, _policyDetails.policyNumber);
    }

    function verifyClaim(address _policyHolder) external onlyInsurer() {
        // Verify the claim and mark it as verified
        uint256 _claimIndex = indeces[_policyHolder] - 1;
        claims[_claimIndex].verified = true;

        uint256 _policyNumber = policyContract.getPolicyNumber(_policyHolder);
        emit ClaimApplicationVerified(_policyHolder, _policyNumber);
    }

    function rejectClaim(address _policyHolder) external onlyInsurer() {
        // Remove the claim from the list
        uint256 _claimIndex = indeces[_policyHolder] - 1;
        _removeItem(_claimIndex);
        
        uint256 _policyNumber = policyContract.getPolicyNumber(_policyHolder);
        emit ClaimApplicationRejected(_policyHolder, _policyNumber);
    }

    function payClaim(address _policyHolder) external onlyInsurer() {
        // Check that the claim has been verified and is not already paid
        uint256 _claimIndex = indeces[_policyHolder] - 1;
        require(claims[_claimIndex].verified == true, "Claim has not been verified");
        require(claims[_claimIndex].paid == false, "Claim has already been paid");

        // Mark the claim as paid
        claims[_claimIndex].paid = true;

        // Transfer the claim amount to the policy holder and decrease policy limit
        policyContract.payClaim(payable(_policyHolder), claims[_claimIndex].amount);

        // Remove the claim from the list
        uint256 _policyNumber = policyContract.getPolicyNumber(_policyHolder);
        _removeItem(_claimIndex);
        emit ClaimApplicationApproved(_policyHolder, _policyNumber);
    }

    function _removeItem(uint256 _index) internal {
        indeces[claims[_index].policyHolder] = 0;
        indeces[claims[claims.length - 1].policyHolder] = _index + 1;
        claims[_index] = claims[claims.length - 1];
        claims.pop();
    }
}
