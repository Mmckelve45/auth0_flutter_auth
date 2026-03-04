import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RawTokenCard extends StatelessWidget {
  final String title;
  final String token;
  const RawTokenCard({required this.title, required this.token});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: cs.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.vpn_key, size: 18, color: cs.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: cs.onSecondaryContainer)),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$title copied'),
                        duration: const Duration(seconds: 1)));
                  },
                  tooltip: 'Copy token',
                  visualDensity: VisualDensity.compact,
                  color: cs.onSecondaryContainer,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(token,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                maxLines: 4),
          ),
        ],
      ),
    );
  }
}
