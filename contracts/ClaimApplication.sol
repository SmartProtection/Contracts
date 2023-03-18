// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.18;
import "./Globals.sol";
import "./ContractRegistry.sol";
import "./Policy.sol";

/**
 * @title ClaimApplication
 * @dev A contract for submitting, verifying, approving, and rejecting claims by policy holders.
 */
contract ClaimApplication {
    struct Claim {
        address policyHolder;
        uint256 amount;
        bool verified;
        bool paid;
    }

    ContractRegistry contractRegistry;

    Claim[] private claims;

    mapping(address => uint256) indeces;

    event ClaimApplicationSubmitted(
        address _policyHolder,
        uint256 _policyNumber
    );
    event ClaimApplicationVerified(
        address _policyHolder,
        uint256 _policyNumber
    );
    event ClaimApplicationApproved(
        address _policyHolder,
        uint256 _policyNumber
    );
    event ClaimApplicationRejected(
        address _policyHolder,
        uint256 _policyNumber
    );

    modifier onlyInsurer() {
        Policy policyContract = Policy(
            payable(contractRegistry.getContract(REGISTRY_KEY_POLICY))
        );
        address payable insurer = payable(policyContract.insurer());
        require(msg.sender == insurer, "Only the insurer can verify claims");
        _;
    }

    modifier hasClaimApplication(address _policyHolder) {
        uint256 _claimIndex = indeces[_policyHolder];
        require(
            _claimIndex != 0,
            "Policy holder doesn't have any claim applications"
        );
        _;
    }

    constructor(address _contractregistryAddress) {
        contractRegistry = ContractRegistry(_contractregistryAddress);
    }

    /**
     * @notice Submit a claim to the policy contract
     * @dev Only policy holders can submit claims
     * @dev The claim amount must be greater than zero
     * @dev The policy must be active
     * @dev The payment deadline should not be missed
     * @dev The policy should not have expired
     * @dev The policyholder should pay the deductible for applying
     * @param _ClaimAmount The amount the policy holder is claiming
     * @return None
     */
    function submitClaim(uint256 _ClaimAmount) external payable {
        Policy policyContract = Policy(
            payable(contractRegistry.getContract(REGISTRY_KEY_POLICY))
        );
        Policy.PolicyDetails memory _policyDetails = policyContract
            .getPolicyDetails(msg.sender);
        require(
            msg.value == _policyDetails.deductible,
            "Policyholder should pay deductible for applying"
        );
        require(_ClaimAmount > 0, "Claim amount must be greater than zero");
        require(
            policyContract.isPolicyHolder(msg.sender),
            "Only policy holders can submit claims"
        );
        require(
            policyContract.isPolicyStarted(msg.sender),
            "Policy isn't activated"
        );
        require(
            policyContract.isPolicyDeadlineValid(msg.sender),
            "Pyment deadline has been missed. The policy is inactive"
        );
        require(
            policyContract.isPolicyEndTimeValid(msg.sender),
            "Policy expired"
        );
        require(
            indeces[msg.sender] == 0,
            "Policy holder has already applied for claim"
        );

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

    /**
     * @notice Verify a claim application
     * @dev Only insurers can verify claims
     * @dev The claim must exist
     * @dev The claim shouldn't be verified
     * @param _policyHolder The policy holder who submitted the claim
     * @return None
     */
    function verifyClaim(
        address _policyHolder
    ) external hasClaimApplication(_policyHolder) onlyInsurer {
        Policy policyContract = Policy(
            payable(contractRegistry.getContract(REGISTRY_KEY_POLICY))
        );
        // Verify the claim and mark it as verified
        uint256 _claimIndex = indeces[_policyHolder] - 1;
        claims[_claimIndex].verified = true;

        uint256 _policyNumber = policyContract.getPolicyNumber(_policyHolder);
        emit ClaimApplicationVerified(_policyHolder, _policyNumber);
    }

    /**
     * @notice Reject a claim application
     * @dev Only insurers can reject claims
     * @dev The claim must exist
     * @param _policyHolder The policy holder who submitted the claim
     * @return None
     */
    function rejectClaim(
        address _policyHolder
    ) external hasClaimApplication(_policyHolder) onlyInsurer {
        Policy policyContract = Policy(
            payable(contractRegistry.getContract(REGISTRY_KEY_POLICY))
        );
        // Remove the claim from the list
        _removeItem(_policyHolder);

        uint256 _policyNumber = policyContract.getPolicyNumber(_policyHolder);
        emit ClaimApplicationRejected(_policyHolder, _policyNumber);
    }

    /**
     * @notice Pay out a claim to the policy holder
     * @dev Only insurers can pay out claims
     * @dev The claim must exist, be verified, and not already be paid out
     * @param _policyHolder The policy holder who submitted the claim
     * @return None
     */
    function payClaim(address _policyHolder) external onlyInsurer {
        Policy policyContract = Policy(
            payable(contractRegistry.getContract(REGISTRY_KEY_POLICY))
        );
        uint256 _policyNumber = policyContract.getPolicyNumber(_policyHolder);
        // Check that the claim has been verified and is not already paid
        uint256 _claimIndex = indeces[_policyHolder] - 1;
        require(
            claims[_claimIndex].verified == true,
            "Claim has not been verified"
        );
        require(
            claims[_claimIndex].paid == false,
            "Claim has already been paid"
        );

        // Mark the claim as paid
        claims[_claimIndex].paid = true;

        // Transfer the claim amount to the policy holder and remove claim from list
        uint256 _claimAmount = claims[_claimIndex].amount;
        _removeItem(_policyHolder);
        policyContract.payClaim(payable(_policyHolder), _claimAmount);

        emit ClaimApplicationApproved(_policyHolder, _policyNumber);
    }

    /**
     * @notice Get details of a claim
     * @dev The claim must exist.
     * @param _policyHolder The policy holder who submitted the claim
     * @return The details of the claim
     */
    function getClaim(
        address _policyHolder
    ) public view hasClaimApplication(_policyHolder) returns (Claim memory) {
        return claims[indeces[_policyHolder] - 1];
    }

    function _removeItem(
        address _policyHolder
    ) internal hasClaimApplication(_policyHolder) {
        uint256 _claimIndex = indeces[_policyHolder];

        indeces[_policyHolder] = 0;
        if (claims.length != _claimIndex) {
            indeces[claims[claims.length - 1].policyHolder] = _claimIndex;
            claims[_claimIndex - 1] = claims[claims.length - 1];
        }
        claims.pop();
    }
}
