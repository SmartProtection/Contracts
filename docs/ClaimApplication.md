## `ClaimApplication`



A contract for submitting, verifying, approving, and rejecting claims by policy holders.

### `onlyInsurer()`





### `checkClaimApplication(address _policyHolder)`






### `constructor(address _contractregistryAddress)` (public)





### `submitClaim(uint256 _ClaimAmount)` (external)

Submit a claim to the policy contract


Only policy holders can submit claims
The claim amount must be greater than zero
The policy must be active
The payment deadline should not be missed
The policy should not have expired
The policyholder should pay the deductible for applying


### `verifyClaim(address _policyHolder)` (external)

Verify a claim application


Only insurers can verify claims
The claim must exist
The claim shouldn't be verified


### `rejectClaim(address _policyHolder)` (external)

Reject a claim application


Only insurers can reject claims
The claim must exist


### `payClaim(address _policyHolder)` (external)

Pay out a claim to the policy holder


Only insurers can pay out claims
The claim must exist, be verified, and not already be paid out


### `getClaim(address _policyHolder) → struct ClaimApplication.Claim` (public)

Get details of a claim


The claim must exist.


### `hasClaimApplication() → bool` (public)

Check whether account has a claim application




### `getClaims() → struct ClaimApplication.Claim[]` (public)





### `_removeItem(address _policyHolder)` (internal)






### `ClaimApplicationSubmitted(address _policyHolder, uint256 _policyNumber)`





### `ClaimApplicationVerified(address _policyHolder, uint256 _policyNumber)`





### `ClaimApplicationApproved(address _policyHolder, uint256 _policyNumber)`





### `ClaimApplicationRejected(address _policyHolder, uint256 _policyNumber)`






### `Claim`


address policyHolder


uint256 amount


bool verified


bool paid



