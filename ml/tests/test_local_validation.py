import unittest
from ml.local_validation import validate

class LocalValidationTests(unittest.TestCase):
    def row(self, **changes):
        return dict(text="The agreed rooms were clean.",label="positive",language="English",group_id="anonymous-job-1",
                    source="consented local review",permission_or_license="study-consent-ref",redacted="yes",
                    reviewer_1_id="reviewer-a",reviewer_2_id="reviewer-b",reviewer_1_label="positive",reviewer_2_label="positive",
                    native_speaker_verified="",adjudicator_id="",adjudication_notes="",**changes)
    def test_no_labels_are_invented(self):
        with self.assertRaisesRegex(ValueError,"No human-labeled"):
            validate([])
        row=self.row();row['label']=''
        with self.assertRaisesRegex(ValueError,"labels"):
            validate([row])
    def test_independence_permission_and_redaction_are_required(self):
        for key,value in [('permission_or_license',''),('redacted','no'),('reviewer_2_id','reviewer-a')]:
            row=self.row();row[key]=value
            with self.assertRaises(ValueError):validate([row])
    def test_disagreement_must_be_resolved(self):
        row=self.row();row['reviewer_2_label']='neutral'
        with self.assertRaisesRegex(ValueError,'disagreement'):validate([row])
        row.update(adjudicator_id='reviewer-c',adjudication_notes='Agreed this explicitly praises the result.')
        self.assertEqual(validate([row])[0]['label'],'positive')
    def test_cebuano_requires_native_review_and_duplicates_are_rejected(self):
        row=self.row();row['language']='Cebuano/Bisaya'
        with self.assertRaisesRegex(ValueError,'native-speaker'):validate([row])
        row['native_speaker_verified']='yes'
        self.assertEqual(len(validate([row])),1)
        with self.assertRaisesRegex(ValueError,'duplicate'):validate([row,row.copy()])

if __name__=='__main__':unittest.main()
