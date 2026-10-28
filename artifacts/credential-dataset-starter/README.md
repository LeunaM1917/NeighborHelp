# Credential extraction starter dataset

This is a prototype dataset for NeighborHelp certificate text extraction and deterministic review checks. It contains **100 clearly marked synthetic PNGs** with fictional holders, issuers and certificate numbers. It contains no TESDA or PRC credentials, official logos, seals, signatures, or real registry results.

**This dataset cannot train or validate certificate authenticity, fraud detection, provider trustworthiness, or real-world TESDA/PRC performance.** All authenticity labels are `unknown_not_evaluated`. Expired and mismatched credentials are review conditions, not evidence that a person is a scammer.

## Contents and use

- `dataset/train/`: 60 images across three layouts.
- `dataset/validation/`: 20 images using a fourth layout.
- `dataset/test/`: 20 images using a fifth layout.
- `dataset/*.jsonl`: one ground-truth record per image, including fields, SHA-256, layout, context and expected rule flags.
- `generate.ps1`: reproducible Windows PowerShell generator using System.Drawing; no additional packages required.

Run `./generate.ps1` from Windows PowerShell to regenerate. Labels are a neutral starter format, not a ready-to-import format for a particular training service. Convert them to your chosen model's schema before fine-tuning. Train on `train`, select settings on `validation`, and reserve `test` for final evaluation. Any augmented copies of an image must stay in its original split. Layouts are separated, but some names and values repeat; this small synthetic split is not a real-world benchmark.

Extract `holder_name`, `issuer`, `qualification`, `certificate_number`, `issue_date` and `expiration_date`. A missing certificate number is labeled JSON `null` and shown as `[not provided]`. Context comes from the application rather than the image. Compare the extracted holder with the profile name, check for a missing number and compare expiration with the fixed reference date, 2026-10-28. Rule flags should be implemented as ordinary validation code; they do not require a trained model. Empty flags do not mean approved or authentic.

All samples have a readable, horizontal layout and conspicuous synthetic notices. They do not represent camera blur, glare, damaged pages, official layouts or real forgery techniques. Do not report extraction results on these images as real-certificate accuracy.

## Getting real examples

1. Start with one credential family relevant to your services, such as TESDA NC/COC, rather than mixing licenses and training certificates immediately.
2. Ask a local training center or willing credential holders for copies explicitly permitted for this research and for model training. A research-use request is not permission to upload documents to an external AI service; clarify that separately if needed. No outreach has been sent as part of this starter kit.
3. Keep originals private. Minimize unrelated personal data, restrict access, and keep consent and provenance records outside a distributable dataset. Public visibility does not establish permission to reuse a certificate for training.
4. Have a human transcribe the extraction fields and review them. Keep issuer-verification evidence separate from transcription labels. A plausible layout or an admin approval is not a verified-authentic label.
5. Create a held-out real test set separated by holder and source document. Keep scans, photos, crops and other variants of each original in the same split. Include varied layouts and image quality; measure field accuracy, missing-field errors and review routing before using the model operationally.

There is no universal document count that guarantees accuracy. Use these 100 synthetic examples for a pipeline smoke test, then choose the size of the real dataset based on observed errors and document variation.

## Official resources checked on 2026-10-28

- TESDA Registry of Certified Workers: https://www.tesda.gov.ph/rwac
- PRC official online services, including license verification: https://online3.prc.gov.ph/
- Document AI Custom Extractor overview: https://docs.cloud.google.com/document-ai/docs/custom-extractor-overview
- Google Document AI training tutorial with synthetic tax forms (a learning example, not Philippine credentials): https://codelabs.developers.google.com/codelabs/docai-custom

Registry pages are verification resources, not image datasets or evidence of an available automation API. Use official verification during admin review; an unavailable or unmatched lookup needs investigation and is not by itself proof of fraud.

## Reuse

The original fictional images, generated labels and generator in this starter kit are made available under CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/. This does not cover any linked external material or later-added real documents. No model has been trained with this kit, and the application has not been changed.
