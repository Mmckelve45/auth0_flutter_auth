import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResultBox extends StatelessWidget {
  final String text;
  final bool isError;

  const ResultBox({required this.text, this.isError = false, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              text,
              style:
                  TextStyle(fontFamily: 'monospace', fontSize: 11, color: fg),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Copied'), duration: Duration(seconds: 1)),
              );
            },
            child: Icon(Icons.copy, size: 14, color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
