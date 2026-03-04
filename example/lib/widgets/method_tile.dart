import 'package:flutter/material.dart';
import 'result_box.dart';

String truncate(String s, [int len = 30]) =>
    s.length > len ? '${s.substring(0, len)}...' : s;

class MethodTile extends StatefulWidget {
  final String name;
  final String description;
  final Future<String> Function() onRun;

  const MethodTile({
    required this.name,
    required this.description,
    required this.onRun,
    super.key,
  });

  @override
  State<MethodTile> createState() => _MethodTileState();
}

class _MethodTileState extends State<MethodTile> {
  bool _loading = false;
  String? _result;
  bool _isError = false;

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });
    try {
      final r = await widget.onRun();
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = e.toString();
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontFamily: 'monospace', fontSize: 13)),
                ),
                SizedBox(
                  height: 32,
                  child: FilledButton.tonal(
                    onPressed: _loading ? null : _run,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Run'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (_result != null) ...[
              const SizedBox(height: 8),
              ResultBox(text: _result!, isError: _isError),
            ],
          ],
        ),
      ),
    );
  }
}
