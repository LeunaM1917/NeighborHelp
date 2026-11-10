import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_upload.dart';

class ReportPhotoPicker extends StatefulWidget {
  const ReportPhotoPicker({
    super.key,
    required this.photos,
    required this.onChanged,
    this.pickPhotos,
  });
  final List<Uint8List> photos;
  final ValueChanged<List<Uint8List>> onChanged;
  final Future<List<Uint8List>> Function()? pickPhotos;
  @override
  State<ReportPhotoPicker> createState() => _ReportPhotoPickerState();
}

class _ReportPhotoPickerState extends State<ReportPhotoPicker> {
  bool _picking = false;
  String? _error;
  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final List<Uint8List> added;
      if (widget.pickPhotos != null) {
        added = await widget.pickPhotos!();
      } else {
        final files = await ImagePicker().pickMultiImage(
          imageQuality: 85,
          maxWidth: 2000,
        );
        added = [for (final file in files) await file.readAsBytes()];
      }
      if (!mounted) return;
      if (added.length + widget.photos.length > 5) {
        throw StateError('Attach at most 5 photos.');
      }
      for (final bytes in added) {
        if (bytes.length > 5 * 1024 * 1024) {
          throw StateError('Each photo must be 5 MB or smaller.');
        }
        ImageUploadFormat.inspect(bytes);
      }
      widget.onChanged([...widget.photos, ...added]);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Choose JPG, PNG or WebP photos up to 5 MB each.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _picking || widget.photos.length >= 5 ? null : _pick,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_picking ? 'Selecting photos…' : 'Add photos (optional)'),
      ),
      const Text(
        'Up to 5 JPG, PNG or WebP photos, 5 MB each. Include only evidence relevant to this report.',
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (widget.photos.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.photos.length; i++)
              InputChip(
                label: Text('Photo ${i + 1}'),
                avatar: const Icon(Icons.image_outlined, size: 18),
                onDeleted: () =>
                    widget.onChanged([...widget.photos]..removeAt(i)),
              ),
          ],
        ),
    ],
  );
}
