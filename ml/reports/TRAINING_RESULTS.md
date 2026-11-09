# Algorithm training results

Sentiment candidates were trained locally on human-labeled public review data. The current production model and provider-ranking weights remain unchanged.

The combined English and Filipino-English experiment used 11,544 training reviews, 2,620 validation reviews and 4,947 test reviews. Vocabulary and fitting used training data only. Regularization and stopping used validation data.

- Existing LSTM: 47.38% test accuracy; macro F1 0.4683.
- New bilingual BiLSTM: 70.08% accuracy; macro F1 0.7019.
- New word/character classifier: 73.16% accuracy; macro F1 0.7323. This candidate had the stronger shared validation score.
- Filipino-English FiReCS subset, selected classifier: 80.14% accuracy.
- English DynaSent subset, selected classifier: 60.94% accuracy. English remains a clear improvement area.

The initial FiReCS-only BiLSTM reached 79.95% accuracy on its own 3,147-review benchmark, versus 52.02% for the original model. Do not compare this single-source score directly with the combined benchmark score.

No Cebuano/Bisaya training or accuracy claim is made. Public data used here covers English and Tagalog/Taglish. Thirty AI-authored Cebuano drafts are provided for correction and labeling by native speakers; they are neither customer reviews nor a gold test set.

The ranking packet contains 45 hypothetical requests and 225 fictional provider candidates, all currently unlabeled. Training rejects this packet until independent human grades and label provenance are supplied. Eligibility remains fixed. Proximity is a geographic calculation; the future fit learns only relative P/R/A/C weights.

## Saved artifacts

- Selected experimental classifier: `../runs/bilingual-linear-2026-11-09/model.joblib` and adjacent metadata.
- Bilingual LSTM: `../runs/bilingual-pilot-2026-11-09/model.keras`.
- FiReCS-only LSTM: `../runs/firecs-pilot-2026-11-09/model.keras`.
- Complete metrics, hashes, dataset provenance and environment: `training-2026-11-09.json`.
- Human labeling packet and rubric: `../labeling/README.md`.

The original LSTM was not overwritten. Generated checkpoints and raw datasets are intentionally ignored by Git; retain the local run folders with your project backup. Training commands are in `../README.md`.

## Limits before real use

Metrics are public benchmark results, not a claim about NeighborHelp users. The old model's original training data is unknown, and benchmark test partitions have been examined during pilot comparisons. Collect fresh service-domain validation, especially independently labeled Cebuano/Bisaya reviews, before deployment or multilingual accuracy claims. The separate per-source results must accompany any pooled accuracy claim.

Data attribution: [FiReCS by Cosme and De Leon](https://huggingface.co/datasets/ccosme/FiReCS) and [DynaSent by Potts, Wu, Geiger and Kiela](https://github.com/cgpotts/dynasent), both data CC BY 4.0. Pinned source revisions and required attribution are retained in the JSON report.
