import '../models/identity_verification.dart';

/// Explanations of saved vendor warnings, not independent findings about an ID.
List<String> identityVerificationIssues(IdentityVerification verification) {
  const descriptions = <String, String>{
    'UNRECOGNIZED_DOCUMENT':
        'The front of the ID could not be recognized. Retake a clear photo of the whole ID.',
    'UNRECOGNIZED_BACK_DOCUMENT':
        'The back of the ID could not be recognized. Retake the back with all text visible and in focus.',
    'INVALID_BACK_DOCUMENT':
        'The back image did not match a valid ID back. Check the selected ID and photograph its back again.',
    'IMAGE_TOO_BLURRY':
        'The ID photo was too blurry. Hold the camera steady and focus before taking another photo.',
    'IMAGE_TOO_SMALL':
        'The ID image was too small. Move closer while keeping all four corners visible.',
    'LOW_TEXT_CONFIDENCE':
        'The ID text could not be read confidently. Retake the photo with better lighting and no glare.',
    'DOCUMENT_FACE_NOT_FOUND':
        'The portrait on the ID could not be detected. Retake the ID photo with the portrait visible.',
    'SELFIE_FACE_NOT_FOUND':
        'No face was detected in the selfie. Take another selfie with the whole face visible.',
    'SELFIE_MULTIPLE_FACES':
        'More than one face was detected in the selfie. Only the person being verified should be in the photo.',
    'INVALID_CAMERA_PERSPECTIVE':
        'The ID was photographed at an unsuitable angle. Place it flat and hold the camera directly above it.',
    'DOCUMENT_FACE_LANDMARK_ERR':
        'The portrait on the ID could not be analyzed clearly. Retake a sharper ID photo.',
    'SELFIE_FACE_LANDMARK_ERR':
        'The selfie could not be analyzed clearly. Retake it facing the camera in good lighting.',
    'MISSING_NAME':
        'The name could not be read from the ID. Retake the photo with the name visible.',
    'MISSING_DOCUMENT_NUMBER':
        'The document number could not be read. Retake the photo without covering or cropping the number.',
    'PHYSICAL_DOCUMENT_MISSING':
        'The physical ID could not be detected. Photograph the original document.',
    'FAKE_ID':
        'ID Analyzer flagged the document as potentially fake. Review the original verification result before deciding.',
    'FACE_MISMATCH':
        'ID Analyzer reported that the selfie did not match the portrait on the ID.',
    'DOCUMENT_FACE_MISMATCH':
        'ID Analyzer reported inconsistent portraits between the document images.',
    'FACE_LIVENESS_ERR':
        'The selfie did not pass the liveness check. The user needs to complete the live face check again.',
    'RECAPTURED_FACE':
        'ID Analyzer flagged the face image as possibly photographed from another image or screen.',
    'DOCUMENT_EXPIRED':
        'The ID was reported as expired. The user needs a valid, unexpired document.',
    'COUNTRY_NOT_ACCEPTED':
        'The issuing country did not match the countries accepted for this verification.',
    'TYPE_NOT_ACCEPTED':
        'The document type did not match the types accepted for this verification.',
    'IMAGE_FORGERY':
        'ID Analyzer flagged possible image manipulation. Review the original verification result.',
    'IMAGE_EDITED':
        'ID Analyzer detected possible image editing. Review the original verification result.',
    'TEXT_FORGERY':
        'ID Analyzer flagged possible text manipulation. Review the original verification result.',
    'ARTIFICIAL_TEXT':
        'ID Analyzer flagged text that may have been altered or artificially added.',
    'MISSING_ENDORSEMENT':
        'Licence endorsement details could not be found or read. This warning alone does not establish that the licence is invalid.',
    'MISSING_EXPIRY_DATE':
        'An expiry date could not be read. Review whether this document type has an expiry date.',
    'MISSING_ISSUE_DATE': 'An issue date could not be read from the document.',
    'MISSING_BIRTH_DATE':
        'The date of birth could not be read from the document.',
    'GLARE_DETECTED':
        'Glare was detected on the document. Retake it away from direct reflections.',
  };
  final issues = verification.verificationIssueCodes
      .map(
        (code) =>
            descriptions[code] ??
            'ID Analyzer reported an additional issue. Review its original transaction for more details.',
      )
      .toSet()
      .toList();
  if (issues.isNotEmpty) return issues;
  if (verification.verificationRetakeRequired) {
    return [
      'The ID or selfie could not be read clearly. Ask the user to retake verification with clear, well-lit photos.',
    ];
  }
  final status = verification.diditStatus.trim().toLowerCase();
  if (status == 'expired') {
    return [
      'The verification link expired before completion. The user needs to start a new verification attempt.',
    ];
  }
  if (verification.isIncomplete) {
    return [
      'The user has not finished the ID and face check. No completed result is available yet.',
    ];
  }
  if (verification.isDeclined) {
    return [
      'This verification was rejected or declined, but no detailed reason was saved. Refresh the status to check for available issue details.',
    ];
  }
  if (status == 'in review') {
    return [
      'ID Analyzer marked this verification for review, but no specific issue was saved. Refresh the status to check for available details.',
    ];
  }
  return ['No verification issues were saved for this application.'];
}
