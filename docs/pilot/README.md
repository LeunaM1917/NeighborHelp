# Panabo user pilot and local validation

Status: prepared, not conducted. No real participant results, human labels, legal approval or Cebuano accuracy are claimed. Keep the academic paper edits with the team, as requested.

## Participants and consent

Recruit a small formative pilot of 5 customers, 5 TESDA-qualified providers and 1 system administrator in Panabo. Include Android and web, older phones, participants who prefer each target language and people with limited connectivity. This sample finds workflow problems; it does not establish population-level accuracy or safety.

Explain this is a prototype, participation is voluntary and they can stop. Use test accounts, fictional addresses, dummy certificates clearly labeled as fixtures, and simulated payment references. Never represent a fixture as a verified live certificate. For a later live study, obtain the institution's required consent and data-handling approval before collecting personal information. Agree retention and deletion dates. Do not record names, exact addresses, passwords or account credentials in observations. Keep any permitted session recordings separately with restricted access.

Approved-provider fixtures may be seeded only in the test project to simulate eligibility. The administrator should reject a dummy certificate when the real registry does not match it. Test actual registry-based approval only with a legitimate holder's permission and matching record; a simulated approved fixture is never evidence of a real credential.

## Session script

1. Customer: find qualified providers for a specified location, 2 consecutive days and 3 hours per day. Include a provider available now but busy during the requested window, one whose second day is disabled and one outside coverage. Ask the customer to explain why the eligible options remain.
2. Customer: discuss requirements with 3 providers. Compare scope, materials, fixed versus daily price and schedule. Prepare an offer; read its complete terms and voluntarily accept. An unanswered inquiry must not allow an offer.
3. Provider: review the exact offer, request a change to an unsuitable offer, accept the revised one, then start at its scheduled time. Race two conflicting acceptances in separate sessions; only one may succeed. Check the 15-minute gap.
4. Either party: propose added scope, materials or days. Reject once and verify the old terms still apply. Propose again; the other person accepts the exact text. Both download original and amended records and explain the new total.
5. Provider: report fixed-price work finished before the schedule ends. Customer requests a specific correction, provider addresses it and reports again, customer confirms. No review or completion credit before confirmation. For daily pricing, follow the agreed daily work period or mutually amend it.
6. Customer: record a simulated partial payment. Provider disputes the first report and acknowledges a corrected report. Explain received, pending and outstanding amounts. Job completion must not acknowledge payment, and an acknowledgment must not complete work.
7. Customer/provider: report and block an inquiry before hiring. Verify messages, photos and new offers stop, history remains visible and only the person who blocked can remove their own block. Administrator sees the report and shared text evidence, records a decision and cannot browse unrelated private chats.
8. Administrator: use the official TESDA registry, compare holder, qualification, certificate number and validity against the uploaded certificate, then approve or reject with notes. Verify an expired or mismatched qualification is excluded. PRC-only professions remain unsupported.
9. Both parties: write an honest mixed review whose stars differ from detected sentiment. Keep the stars and wording via Post as written. Repeat in English, Tagalog/Taglish and native-reviewed Cebuano/Bisaya; record model mistakes rather than correcting human opinions to fit predictions.
10. Connectivity: disconnect during send, offer acceptance, amendment acceptance, payment acknowledgment and completion confirmation. Restore connectivity; verify the final server state before retrying. Reopen the app and follow the notification to the correct record. Check for duplicate counters, payments or agreements. A client timeout is an unknown outcome until refreshed.

Use a separate test Firebase project; never clear live Firestore for a pilot. Reset a session only after preserving authorized observations. Do not perform real regulated work or real payments during the prototype exercise.

## Observation form

Copy `session-template.json` per participant. Record task success without help, success with help, failed, time in seconds, errors, confusing labels, exact device/browser/network conditions and a 1–5 ease rating. Record only anonymous session identifiers. Count incomplete tasks and timeouts in denominators; retain failures.

Before sessions, register formative targets: at least 80% unassisted completion for each core task, zero unauthorized access or double booking in the scripted checks, zero duplicate payment acknowledgments or completion credits, and complete agreement/receipt comprehension by both parties. These are team acceptance targets, not measured results. Any security or contract-consent failure blocks a live pilot until fixed, regardless of average task success.

For ranking, compare unchanged 40/30/20/10 weights with a candidate only on independently labeled held-out requests. Report NDCG@5, unsuitable-provider rate, no-result rate, coverage errors, latency and reasons. Log features as they appeared at search time; later ratings and completion totals must never be used as historical inputs. Keep every candidate for a request in the same split and do not label by copying the app's score.

## Local sentiment collection and frozen evaluation

```powershell
python -m ml.local_validation --template --output ml/data/local-collection
# Humans fill ml/data/local-collection/local_reviews.csv; this command creates no labels.
python -m ml.local_validation --data ml/data/local-collection/local_reviews.csv --output ml/data/local-frozen-v1
python -m ml.sentiment_linear_train --data ml/data/local-frozen-v1/reviews.csv --output ml/runs/local-linear-v1 --source "Permissioned local service reviews; two independent human labels and adjudication" --languages "English,Tagalog/Taglish,Cebuano/Bisaya"
```

Collect actual service reviews with permission; remove identifying details, include neutral factual comments, negation, mixed sentiment and spelling variants. Use two different reviewers without model predictions or stars visible. Cebuano requires native-speaker verification. Group paraphrases, translations and the same underlying job together. Resolve disagreements and retain the annotation record securely.

The freezer refuses incomplete permission/redaction records, missing independent labels, unresolved disagreements, duplicate text, unverified Cebuano and insufficient per-language/class coverage in any split. Its minimum of 10 per class/language/split is an engineering guard, not a statistical adequacy claim. Collect a larger representative corpus and choose a sample size suitable for the intended accuracy claim with your adviser. Preserve the source and frozen manifest hashes, hold test data aside, tune only on train/validation, and report macro-F1, per-class recall, confusion matrices, calibration and results separately for each language. Do not publish pooled bilingual accuracy as Cebuano performance. Promotion of any candidate is a separate evidence-based decision; these tools do not change production models or ranking weights.

The existing hypothetical matching packet and AI-authored Cebuano drafts in `ml/labeling` remain separate exercises, never actual pilot results or independent real-world validation.

## Required external reviews

Have the instructor/validator review the pilot protocol and relevant qualified Philippine counsel review the actual contract, amendment, cancellation, payment and dispute flow before making legal-compliance claims or a live rollout. The repository's template is not a legal opinion. Native speakers must review language quality. Register Firebase App Check providers and monitor valid-client metrics before enforcing; see [rollout instructions](../marketplace-improvements.md). No production deployment or console registration was performed by this local implementation.
