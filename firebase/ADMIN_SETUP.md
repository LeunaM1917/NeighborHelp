# Individual administrator accounts

For the barangay privacy migration, unified chat, time off and offer expiry rollout, see [the rollout guide](../docs/barangays-chat-and-offers.md). Deploy matching client/rules/Functions and review the count-only migration plan before applying it.

The shared demo credential and local administrator fallback have been removed. A failed Firebase sign-in never opens an administrator preview.

1. Create one Firebase Authentication account per authorized administrator, with an email they own and a unique strong password or Google sign-in. Do not share accounts or reuse a publicly documented demonstration password.
2. In a trusted Firebase console, create/review `users/{AUTH_UID}` with their `fullName`, `email`, `role: "Administrator"`, `accountStatus: "Active"`, and server timestamps for `createdAt`/`updatedAt`. The document ID must match the Firebase Authentication UID. Public registration cannot assign an administrator role.
3. Sign in with the administrator account. The console and matching rules/callables no longer require email verification; the trusted Administrator role and Active account status determine access.
4. Confirm the individual accounts work before retiring a legacy shared account. Rotate its known password and disable it through Firebase Authentication after arranging account recovery. This code does not automatically change existing cloud credentials.

On 2026-11-10, the email-verification prerequisite was removed at the user's request. Matching Firestore/Storage rules and the six affected administrator command functions were deployed to `neighborhelp-63771`. Hot-restart a running localhost client to load the updated gate. Existing accounts, passwords, assigned roles and MFA policy values were not modified.

## Optional two-step sign-in

Admin settings supports phone MFA enrollment. Both password and Google sign-in handle the second-factor challenge. Follow the official [Flutter MFA setup](https://firebase.google.com/docs/auth/flutter/multi-factor). Identity Platform, SMS regions, signing/domain configuration and provider billing must be configured in the real project. None was enabled here. SMS has security limitations; review stronger factors where supported, and establish an approved account recovery process.

Enroll and test every intended administrator before enforcing MFA. Then, through a trusted console/Admin SDK, set `securityPolicy/admin` to `{ "requireMfa": true }`. Client writes to this document are denied, including for administrators. The root gate, administrator callables, Firestore rules and certificate Storage rules read the same policy. A primary-password token is then insufficient; Firebase must issue a second-factor token. Enrollment alone does not enable the policy or upgrade a primary-only session: sign out and sign in with the second factor.

A missing/false policy allows active administrator accounts during staged setup. An authorized operator can change the policy through the trusted console for approved recovery; the admin UI cannot disable it. Do not require MFA before enrollment/recovery are tested.

Deploy matching Functions, rules and client versions together. No live accounts, passwords, roles or MFA policy were changed by this local implementation.
