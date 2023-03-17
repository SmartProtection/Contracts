// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.18;

import "./Globals.sol";
import "./ContractRegistry.sol";
import "./Underwriting.sol";

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

    ContractRegistry public contractRegistry;
    address payable public insurer;
    uint256 public policyLimit;
    uint256 public deductiblePercentage;
    uint256 public basePolicyTerm;
    uint256 public policyPaymentPeriod;

    mapping(address => PolicyHolder) public policyHolders;
    mapping(uint256 => address) public policyHolderAddresses;
    mapping(uint256 => PolicyDetails) public policies;
    mapping(uint256 => PolicyPayments) public policyPayments;

    event PolicyCreated(address policyHolderAddress, uint256 policyNumber, uint256 premiumAmount);

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

    modifier onlyPremiumPaymentContract() {
        address _premiumPaymentAddress = contractRegistry.getContract(REGISTRY_KEY_PREMIUM_PAYMENT);
        require(msg.sender == _premiumPaymentAddress, "Must be PremiumPayment contract");
        _;
    }

    modifier onlyClaimApplication() {
        address _claimApplicationAddress = contractRegistry.getContract(REGISTRY_KEY_CLAIM_APPLICATION);
        require(msg.sender == _claimApplicationAddress, "Must be ClaimApplication contract");
        _;
    }

    constructor(address _contractregistryAddress) {
        contractRegistry = ContractRegistry(_contractregistryAddress);
        insurer = payable(msg.sender);
        policyLimit = 1000 gwei;
        deductiblePercentage = 10;
        basePolicyTerm = 52 weeks;
        policyPaymentPeriod = 4 weeks;
    }

    function createPolicy(uint8 _age, bool _sex, uint256 _baseTermsNumber) external payable returns(uint256) {
        require(_age > 0, "Age should be greater than 0");
        Underwriting underwriting = Underwriting(contractRegistry.getContract(REGISTRY_KEY_UNDERWRITING));
        require(underwriting.checkEligibility(_age, _sex), "You cannot apply for insurance");

        uint256 _policyNumber = policyHolders[msg.sender].policyNumber;
        uint256 _policyEndDate = policies[_policyNumber].endDate;
        require(_policyNumber == 0 && _policyEndDate <= block.timestamp, "Current user already has a policy");
        require(basePolicyTerm > 0 && _baseTermsNumber < 6, "Policy term must be more than 0 year and less than 6 years");

        // Generate policy number and premium amount
        uint256 _policyTerm = basePolicyTerm * _baseTermsNumber;
        uint256 _premiumAmount = calculatePremium(_age, _sex, _policyTerm, policyLimit);
        _policyNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _premiumAmount)));
        
        require(msg.value == _premiumAmount, "First payment must be equal to premium Amount");

        // Create a new policy holder
        PolicyHolder memory newPolicyHolder = PolicyHolder(msg.sender, _policyNumber, _age, _sex);
        policyHolders[msg.sender] = newPolicyHolder;
        policyHolderAddresses[_policyNumber] = msg.sender;

        // Create a new policy
        uint256 _policyStartDate = block.timestamp;
        uint256 _deductible = _premiumAmount * deductiblePercentage / 100;
        _policyEndDate = _policyStartDate + _policyTerm;
        PolicyDetails memory newPolicy =PolicyDetails(_policyNumber, _policyStartDate, _policyEndDate, _premiumAmount,
            policyLimit, _deductible, _policyTerm, policyPaymentPeriod);
        policies[_policyNumber] = newPolicy;

        // Create policy payments info
        uint256 _nextDeadline = _policyStartDate + policyPaymentPeriod;
        PolicyPayments memory _policyPayments = PolicyPayments(_policyNumber, _nextDeadline, 1);
        policyPayments[_policyNumber] = _policyPayments;

        policyHolderAddresses[_policyNumber] = msg.sender;

        emit PolicyCreated(msg.sender, _policyNumber, _premiumAmount);
        return _policyNumber;
    }

    function updatePremiumPaymentStatus(address _polictHolder)
        external
        payable
        onlyPremiumPaymentContract()
        hasPolicy(_polictHolder)
        policyShouldBeValid(_polictHolder) {
        
        // Receive policy details and payments
        PolicyDetails memory _policyDetails = getPolicyDetails(_polictHolder);
        PolicyPayments storage _policyPayments = policyPayments[_policyDetails.policyNumber];

        // Update policy holder's premium payment status
        _policyPayments.nextDeadline += _policyDetails.paymentPeriod;
        _policyPayments.paidPeriods++;
    }

    function payClaim(address payable _policyHolder, uint256 _claimAmount)
        external
        payable
        onlyClaimApplication() {
        
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

    function calculatePremium(uint8 _age, bool _sex, uint256 _policyTerm, uint256 _policyLimit) public view returns(uint256) {
        uint256 _denominator = (100000000 + (_sex ? 0 : 100)) * _policyTerm;
        return (basePolicyTerm) * _policyLimit * _age / _denominator;
    }
}