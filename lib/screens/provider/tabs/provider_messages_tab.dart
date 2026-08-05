import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../shared/messages_hub.dart';

class ProviderMessagesTab extends StatelessWidget {
  const ProviderMessagesTab({super.key, required this.appUser});

  final AppUser appUser;

  @override
  Widget build(BuildContext context) {
    return MessagesHub(appUser: appUser, asCustomer: false);
  }
}
