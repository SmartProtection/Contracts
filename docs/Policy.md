## `Policy`



This contract implements an insurance policy system. It allows policy holders to create policies, make payments,
and file claims. The contract also manages policy details and payments.

### `hasPolicy(address _policyHolder)`





### `policyShouldBeValid(address _policyHolder)`





### `onlyClaimApplicationContract()`






### `constructor(address _contractRegistryAddress)` (public)





### `receive()` (external)





### `fallback()` (external)





### `createPolicy(uint8 _age, bool _sex, uint256 _baseTermsNumber) → uint256` (external)

Creates a new insurance policy for the caller.


Creates a new insurance policy for the caller.
The policy holder's age must be greater than 0.
The policy holder must be eligible for insurance.
The caller cannot have an existing policy or must have an expired policy.
The policy term must be between 1 and 5 years.

Emits a {PolicyCreated} event.

### `makePayment()` (external)

Allows a policy holder to make a premium payment for their policy.


Allows a policy holder to make a premium payment for their insurance policy.

Requirements:
Caller must have an active insurance policy.
Policy must still be valid and not expired.
Payment amount must be greater than 0 and equal to the premium amount specified in the policy.

### `payClaim(address payable _policyHolder, uint256 _claimAmount)` (external)

Pays the claim amount to the policy holder


This function can only be called by the ClaimApplication contract.
The claim amount should be less than or equal to the policy limit.


### `getBalance() → uint256` (external)





### `isPolicyHolder(address _policyHolder) → bool` (public)





### `isPolicyDeadlineValid(address _policyHolder) → bool` (public)





### `isPolicyDeadlineValid(uint256 _policyNumber) → bool` (public)





### `isPolicyEndTimeValid(address _policyHolder) → bool` (public)





### `isPolicyEndTimeValid(uint256 _policyNumber) → bool` (public)





### `isPolicyStarted(address _policyHolder) → bool` (public)





### `isPolicyStarted(uint256 _policyNumber) → bool` (public)





### `getPolicyDetails(address _policyHolder) → struct Policy.PolicyDetails` (public)





### `getPolicyPayments(address _policyHolder) → struct Policy.PolicyPayments` (public)





### `getPolicyHolder(address _policyHolder) → struct Policy.PolicyHolder` (public)





### `getPolicyNumber(address _policyHolder) → uint256` (public)





### `calculatePremium(uint8 _age, bool _sex, uint256 _baseTermsNumber) → uint256` (public)



Calculates the policy premium based on the provided age, sex, and base policy terms number.


### `checkEligibility(uint256 _age, bool _sex) → bool` (public)



Checks if the policy holder is eligible for the policy.



### `PolicyCreated(address policyHolderAddress, uint256 policyNumber, uint256 premiumAmount)`





### `PremiumPaid(address _policyHolder, uint256 _policyNumber, uint256 _paidPeriods)`






### `PolicyHolder`


address policyHolderAddress


uint256 policyNumber


uint8 age


bool sex


### `PolicyDetails`


uint256 policyNumber


uint256 startDate


uint256 endDate


uint256 premiumAmount


uint256 policyLimit


uint256 deductible


uint256 policyTerm


uint256 paymentPeriod


### `PolicyPayments`


uint256 policyNumber


uint256 nextDeadline


uint256 paidPeriods



