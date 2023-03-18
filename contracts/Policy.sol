// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.18;

import "./ContractRegistry.sol";

/**
 * @title Policy contract
 * @dev This contract implements an insurance policy system. It allows policy holders to create policies, make payments,
 * and file claims. The contract also manages policy details and payments.
 */
contract Policy {
    struct PolicyHolder {
        address policyHolderAddress;    // Policy holder address
        uint256 policyNumber;           // Unique number of the policy
        uint8 age;                      // Policy holder age
        bool sex;                       // Policy holder sex
    }

    struct PolicyDetails {
        uint256 policyNumber;   // Unique number of the policy
        uint256 startDate;      // Commencement date of the insurance policy
        uint256 endDate;        // End date of the insurance policy
        uint256 premiumAmount;  // Monthly premium of the policy
        uint256 policyLimit;    // Maximum claims of the policy
        uint256 deductible;     // Cost of the claims
        uint256 policyTerm;     // Insurance policy validity period
        uint256 paymentPeriod;  // Payment interval
    }

    struct PolicyPayments {
        uint256 policyNumber;   // Unique number of the policy
        uint256 nextDeadline;   // Next date of payment
        uint256 paidPeriods;    // Count of paid periods
    }

    ContractRegistry contractRegistry;
    address payable public insurer;
    uint256 public policyLimit = 1000 gwei;
    uint256 public deductiblePercentage = 10;
    uint256 public basePolicyTerm = 52 weeks;
    uint256 public policyPaymentPeriod = 4 weeks;
    uint256 public policyCreationTime = 5 minutes;

    mapping(address => PolicyHolder) public policyHolders;
    mapping(uint256 => address) public policyHolderAddresses;
    mapping(uint256 => PolicyDetails) public policies;
    mapping(uint256 => PolicyPayments) public policyPayments;

    event PolicyCreated(address policyHolderAddress, uint256 policyNumber, uint256 premiumAmount);
    event PremiumPaid(address _policyHolder, uint256 _policyNumber, uint256 _paidPeriods);

    modifier hasPolicy(address _policyHolder) {
        require(policyHolders[_policyHolder].policyNumber != 0,
            "Current user doesn't have a policy");
        _;
    }

    modifier policyShouldBeValid(address _policyHolder) {
        require(isPolicyDeadlineValid(_policyHolder),
            "Pyment deadline has been missed. The policy is inactive");
        require(isPolicyEndTimeValid(_policyHolder), "Policy expired");
        _;
    }

    modifier onlyClaimApplicationContract() {
        address _claimApplicationAddress = contractRegistry.getContract(REGISTRY_KEY_CLAIM_APPLICATION);
        require(msg.sender == _claimApplicationAddress, "Must be ClaimApplication contract");
        _;
    }

    constructor(address _contractRegistryAddress) {
        contractRegistry = ContractRegistry(_contractRegistryAddress);
        insurer = payable(msg.sender);
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @notice Creates a new insurance policy for the caller.
     * @dev Creates a new insurance policy for the caller.
     * @param _age The age of the policy holder.
     * @param _sex The sex of the policy holder (true for male, false for female).
     * @param _baseTermsNumber The number of years for the policy term.
     * @return uint256 The policy number of the newly created policy.
     *
     * Requirements:
     * @dev The policy holder's age must be greater than 0.
     * @dev The policy holder must be eligible for insurance.
     * @dev The caller cannot have an existing policy or must have an expired policy.
     * @dev The policy term must be between 1 and 5 years.
     *
     * Emits a {PolicyCreated} event.
     */
    function createPolicy(uint8 _age, bool _sex, uint256 _baseTermsNumber) external returns(uint256) {
        require(_age > 0, "Age should be greater than 0");
        require(checkEligibility(_age, _sex), "You cannot apply for insurance");

        uint256 _policyNumber = policyHolders[msg.sender].policyNumber;
        uint256 _policyEndDate = policies[_policyNumber].endDate;
        require(_policyNumber == 0 || _policyEndDate <= block.timestamp, "Current user already has a policy");
        require(_baseTermsNumber > 0 && _baseTermsNumber < 6, "Policy term must be more than 0 year and less than 6 years");

        // Generate policy number and premium amount
        uint256 _policyTerm = basePolicyTerm * _baseTermsNumber;
        uint256 _premiumAmount = calculatePremium(_age, _sex, _baseTermsNumber);
        _policyNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _premiumAmount)));
        
        // Create a new policy holder
        PolicyHolder memory newPolicyHolder = PolicyHolder(msg.sender, _policyNumber, _age, _sex);
        policyHolders[msg.sender] = newPolicyHolder;
        policyHolderAddresses[_policyNumber] = msg.sender;

        // Create a new policy
        uint256 _policyStartDate = block.timestamp + policyCreationTime;
        uint256 _deductible = _premiumAmount * deductiblePercentage / 100;
        _policyEndDate = _policyStartDate + _policyTerm;
        PolicyDetails memory newPolicy = PolicyDetails(_policyNumber, _policyStartDate, _policyEndDate, _premiumAmount,
            policyLimit, _deductible, _policyTerm, policyPaymentPeriod);
        policies[_policyNumber] = newPolicy;

        // Create policy payments info
        policyPayments[_policyNumber] = PolicyPayments(_policyNumber, _policyStartDate, 0);

        policyHolderAddresses[_policyNumber] = msg.sender;

        emit PolicyCreated(msg.sender, _policyNumber, _premiumAmount);
        return _policyNumber;
    }

    /**
     * @notice Allows a policy holder to make a premium payment for their policy.
     * @dev Allows a policy holder to make a premium payment for their insurance policy.
     * 
     * Requirements:
     * @dev Caller must have an active insurance policy.
     * @dev Policy must still be valid and not expired.
     * @dev Payment amount must be greater than 0 and equal to the premium amount specified in the policy.
     */
    function makePayment()
        external
        payable
        hasPolicy(msg.sender)
        policyShouldBeValid(msg.sender) {
        require(msg.value > 0, "Payment amount must be greater than zero");

        PolicyDetails memory _policyDetails = getPolicyDetails(msg.sender);
        PolicyPayments storage _policyPayments = policyPayments[_policyDetails.policyNumber];
        
        require(_policyPayments.nextDeadline <= _policyDetails.endDate,
            "Payment deadline equals to or bigger than Policy end date.");
        require(msg.value == _policyDetails.premiumAmount, "Incorrect payment amount");

        // Update policy holder's premium payment status
        _policyPayments.nextDeadline += _policyDetails.paymentPeriod;
        _policyPayments.paidPeriods += 1;

        emit PremiumPaid(msg.sender, _policyDetails.policyNumber, _policyPayments.paidPeriods);
    }

    /**
     * @notice Pays the claim amount to the policy holder
     * @dev This function can only be called by the ClaimApplication contract.
     * @dev The claim amount should be less than or equal to the policy limit.
     * @param _policyHolder The address of the policy holder
     * @param _claimAmount The amount to be paid to the policy holder
     */
    function payClaim(address payable _policyHolder, uint256 _claimAmount)
        external
        payable
        onlyClaimApplicationContract() {
        
        uint256 _policyNumber = getPolicyNumber(_policyHolder);
        PolicyDetails storage _policyDetails = policies[_policyNumber];
        require(_claimAmount <= _policyDetails.policyLimit,
            "Claim amount should be less than or equal to policy limit");
        _policyDetails.policyLimit -= _claimAmount;

        _policyHolder.transfer(_claimAmount);
    }

    function getBalance() external view returns(uint256) {
        return address(this).balance;
    }

    function isPolicyHolder(address _policyHolder) public view returns(bool) {
        return policyHolders[_policyHolder].policyNumber != 0;
    }

    function isPolicyDeadlineValid(address _policyHolder) public view returns(bool) {
        return isPolicyDeadlineValid(policyHolders[_policyHolder].policyNumber);
    }
    
    function isPolicyDeadlineValid(uint256 _policyNumber) public view returns(bool) {
        PolicyPayments memory _policyPayments = policyPayments[_policyNumber];
        return block.timestamp <= _policyPayments.nextDeadline;
    }

    function isPolicyEndTimeValid(address _policyHolder) public view returns(bool) {
        return isPolicyEndTimeValid(policyHolders[_policyHolder].policyNumber);
    }
    
    function isPolicyEndTimeValid(uint256 _policyNumber) public view returns(bool) {
        PolicyDetails memory _policyDetails = policies[_policyNumber];
        return block.timestamp <= _policyDetails.endDate;
    }

    function isPolicyStarted(address _policyHolder) public view returns(bool) {
        return isPolicyStarted(policyHolders[_policyHolder].policyNumber);
    }
    
    function isPolicyStarted(uint256 _policyNumber) public view returns(bool) {
        PolicyDetails memory _policyDetails = policies[_policyNumber];
        return _policyDetails.startDate <= block.timestamp;
    }

    function getPolicyDetails(address _policyHolder) public view hasPolicy(_policyHolder) returns(PolicyDetails memory) {
        uint256 _policyNumber = policyHolders[_policyHolder].policyNumber;
        PolicyDetails memory _policyDetails = policies[_policyNumber];
        return _policyDetails;
    }

    function getPolicyPayments(address _policyHolder) public view hasPolicy(_policyHolder) returns(PolicyPayments memory) {
        uint256 _policyNumber = policyHolders[_policyHolder].policyNumber;
        PolicyPayments memory _policyPayments = policyPayments[_policyNumber];
        return _policyPayments;
    }

    function getPolicyHolder(address _policyHolder) public view hasPolicy(_policyHolder) returns(PolicyHolder memory) {
        return policyHolders[_policyHolder];
    }

    function getPolicyNumber(address _policyHolder) public view hasPolicy(_policyHolder) returns(uint256) {
        return policyHolders[_policyHolder].policyNumber;
    }

    /**
     * @dev Calculates the policy premium based on the provided age, sex, and base policy terms number.
     * @param _age The age of the policy holder.
     * @param _sex The sex of the policy holder (true for male, false for female).
     * @param _baseTermsNumber The base number of policy terms.
     * @return The calculated policy premium.
     */
    function calculatePremium(uint8 _age, bool _sex, uint256 _baseTermsNumber) public view returns(uint256) {
        uint256 _termsDenominator = 100;
        uint256 _policyLimitDenominator = (10000000 + (_sex ? 0 : 100));
        uint256 _ageDenominator = 10;
        uint256 _denominator = _termsDenominator * _policyLimitDenominator * _ageDenominator;
        uint256 _termsNumerator = (100 - 5 * (_baseTermsNumber - 1));
        uint256 _numerator = policyLimit * _age * _termsNumerator;
        return _numerator / _denominator;
    }
    /**
     * @dev Checks if the policy holder is eligible for the policy.
     * @param _age The age of the policy holder.
     * @param _sex The sex of the policy holder (true for male, false for female).
     * @return True if the policy holder is eligible, false otherwise.
     */
    function checkEligibility(uint256 _age, bool _sex) public pure returns(bool) {
        return (_age > 0 && (_sex || !_sex));
    }
}