/// Government ID options supported by the Didit verification workflow.
///
/// Didit hosted flow accepts: P (passport), ID (national ID), DL (driver license),
/// RP (residence permit). See `createDiditSession` in Cloud Functions.
class PhilippineGovernmentIdType {
  const PhilippineGovernmentIdType({
    required this.label,
    required this.diditCode,
    this.hint,
  });

  final String label;
  final String diditCode;
  final String? hint;

  /// Matches the document types shown in Didit's "Choose your verification document" step.
  static const List<PhilippineGovernmentIdType> options = [
    PhilippineGovernmentIdType(
      label: 'National ID card',
      diditCode: 'ID',
      hint: 'Philippine National ID (PhilID / PhilSys)',
    ),
    PhilippineGovernmentIdType(
      label: 'Passport',
      diditCode: 'P',
      hint: 'Philippine passport (DFA)',
    ),
    PhilippineGovernmentIdType(
      label: "Driver's license",
      diditCode: 'DL',
      hint: 'LTO driver\'s license',
    ),
    PhilippineGovernmentIdType(
      label: 'Residence permit',
      diditCode: 'RP',
      hint: 'ACR I-Card or other residence permit in the Philippines',
    ),
  ];

  static PhilippineGovernmentIdType? fromCode(String code) {
    final upper = code.trim().toUpperCase();
    for (final o in options) {
      if (o.diditCode == upper) return o;
    }
    return null;
  }
}
