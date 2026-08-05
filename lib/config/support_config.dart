/// Platform support contact for account appeals and safety issues.
abstract final class SupportConfig {
  static const appealEmail = 'support@neighborhelp.com';

  static Uri appealMailto({String? userEmail, String? userName}) {
    final subject = Uri.encodeComponent('NeighborHelp account appeal');
    final bodyParts = <String>[
      'Hello NeighborHelp support,',
      '',
      'I would like to appeal the restriction on my account.',
      '',
      if (userName != null && userName.trim().isNotEmpty) 'Full name: ${userName.trim()}',
      if (userEmail != null && userEmail.trim().isNotEmpty) 'Account email: ${userEmail.trim()}',
      '',
      'Reason for appeal:',
      '',
    ];
    final body = Uri.encodeComponent(bodyParts.join('\n'));
    return Uri.parse('mailto:$appealEmail?subject=$subject&body=$body');
  }
}
