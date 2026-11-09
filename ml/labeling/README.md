# Human labeling instructions

The CSV files in this folder are annotation packets, not trained data or evidence of model accuracy. Do not fill labels from the existing algorithm: that would teach the model to repeat its own ranking.

## Provider matches

`provider_matches.csv` contains 45 hypothetical requests, each with five fictional candidates. The distances and histories are invented for the exercise. They are not actual NeighborHelp transactions. No preferred ranking or algorithm score is shown.

Have two people independently grade each candidate using only the information given for that request. A validator familiar with local household services can help resolve disagreements. Use anonymous reviewer identifiers in `label_source`.

- `0`: unsuitable for this request. Also mandatory when identity, certificate, active account or service match is false, or the request is outside either coverage radius.
- `1`: a weak option among the eligible providers.
- `2`: a reasonable option.
- `3`: a strong option. Multiple providers may receive the same grade.

Availability describes the requested period. Consider it along with distance, Bayesian rating, and completion history. Do not reward a high rating simply because the provider has only a few reviews. `bayesian_rating` already includes the application's confidence adjustment.

Fill `reviewer_1_grade` and `reviewer_2_grade` separately. Resolve differences in `adjudication_notes`, put the final 0–3 grade in `relevance`, and record who adjudicated it in `label_source`. Keep query/provider/group identifiers and feature columns unchanged. Preserve the original packet so independent labels can be checked later.

The training tool keeps requests together and creates separate training, validation and test groups. Hypothetical judgments measure alignment with your reviewers, not actual booking success. Real historical data must use features captured before the booking outcome; using today's rating or completion totals to predict old decisions leaks future information.

Train only after all rows are labeled:

```powershell
python -m ml.ranking_train --data ml/labeling/provider_matches.csv --output ml/runs/ranking-human-pilot
```

This writes candidate weights and metrics. It does not change the app's 40/30/20/10 production weights. Qualification, identity and coverage gates remain mandatory regardless of learned weights.

## Cebuano and Bisaya

`cebuano_review_drafts.csv` contains 30 AI-authored draft sentences for native-speaker review. They are not public customer reviews, verified translations, training labels or an independent benchmark. Some deliberately contain mixed sentiment or negation. Thirty drafts are insufficient to establish language-wide accuracy.

Have native Cebuano/Bisaya speakers correct unnatural language in `corrected_text`, independently fill the two reviewer labels, and adjudicate `final_label` as `negative`, `neutral` or `positive`. Record native-speaker verification and disagreements. Keep mixed evaluations and factual neutral reviews distinct: an observation that a worker arrived at 9 AM is not automatically praise.

Use `real_review_collection.csv` to collect a larger representative set with permission or a suitable license. Aim for coverage of all three classes, negation, slang, spelling variants, mixed English/Bisaya, late arrival, incomplete work and factual updates. Keep personal names, phone numbers and exact addresses out of the text. Have two native speakers label independently and adjudicate differences.

For training, use columns `text,label,language,group_id,split,source`. A `group_id` ties a review to its paraphrases or translations so those variants cannot cross splits. Use `train`, `validation`, `test` for every record, or leave every `split` blank for deterministic group splitting. Keep an independently labeled service-review test set aside before tuning. The trainer requires at least 150 unique labeled reviews overall and at least 10 per class in each split; these are basic pilot guards, not proof that the sample is sufficient.

Cebuano remains unverified until appropriate native-speaker data is trained and evaluated. Hiligaynon is not a substitute for Cebuano. Do not publish the Filipino–English benchmark score as a Cebuano score.
