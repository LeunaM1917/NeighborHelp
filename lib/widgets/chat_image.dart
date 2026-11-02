import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

Future<void> sendBookingImage(
  BuildContext context, {
  required String bookingId,
  required String customerId,
  required String providerId,
  required String senderId,
  required String receiverId,
}) async {
  try {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image == null) return;
    if (await image.length() > 5 * 1024 * 1024) {
      throw StateError('Choose an image up to 5 MB.');
    }
    final url = await StorageService().uploadMessageImage(
      bookingId: bookingId,
      senderId: senderId,
      bytes: await image.readAsBytes(),
    );
    await FirestoreService().sendImageMessage(
      bookingId: bookingId,
      customerId: customerId,
      providerId: providerId,
      senderId: senderId,
      receiverId: receiverId,
      mediaUrl: url,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError
                ? e.message.toString()
                : 'Could not send the image. Please retry.',
          ),
        ),
      );
    }
  }
}

class ChatImage extends StatefulWidget {
  const ChatImage({super.key, required this.url});
  final String url;
  @override
  State<ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<ChatImage> {
  late Future<String> _url;
  @override
  void initState() {
    super.initState();
    _url = StorageService().readableUrl(widget.url);
  }

  @override
  void didUpdateWidget(covariant ChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _url = StorageService().readableUrl(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snap) {
      if (snap.hasError) {
        return const Text(
          'Image unavailable. Check your connection or access.',
        );
      }
      if (!snap.hasData) {
        return const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            child: Stack(
              children: [
                InteractiveViewer(
                  child: Image.network(
                    snap.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text('Image unavailable.'),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: Image.network(
          snap.data!,
          width: 240,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text('Image unavailable.'),
        ),
      );
    },
  );
}
