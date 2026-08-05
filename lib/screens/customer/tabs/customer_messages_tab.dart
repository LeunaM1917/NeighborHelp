import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../shared/messages_hub.dart';

class CustomerMessagesTab extends StatelessWidget {
  const CustomerMessagesTab({super.key, required this.appUser, this.scrollController});

  final AppUser appUser;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return MessagesHub(
      appUser: appUser,
      asCustomer: true,
      listScrollController: scrollController,
    );
  }
}
