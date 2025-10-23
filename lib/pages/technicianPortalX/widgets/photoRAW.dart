import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoRow extends StatelessWidget {
  final String label;
  final XFile? single;
  final List<XFile>? many;
  final Future<XFile?> Function() onPickOne;
  final bool requiredMark;

  const PhotoRow.single({
    super.key,
    required this.label,
    required this.single,
    required this.onPickOne,
    this.requiredMark = false,
  }) : many = null;

  const PhotoRow.multi({
    super.key,
    required this.label,
    required this.many,
    required this.onPickOne,
  })  : single = null,
        requiredMark = false;

  @override
  Widget build(BuildContext context) {
    final isMulti = many != null;
    final count = isMulti ? many!.length : (single == null ? 0 : 1);
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w600),
              children: [
                if (requiredMark)
                  const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                TextSpan(
                  text: '  •  ${count == 0 ? "No photo" : "$count photo${count > 1 ? 's' : ''}"}',
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w400),
                )
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () async => await onPickOne(),
          icon: const Icon(Icons.photo_camera),
          label: const Text('Take'),
        )
      ],
    );
  }
}
