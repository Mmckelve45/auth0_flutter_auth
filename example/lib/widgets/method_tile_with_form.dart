import 'package:flutter/material.dart';
import 'result_box.dart';

class MethodTileWithForm extends StatefulWidget {
  final String name;
  final String description;
  final List<String> fields;
  final Map<String, String> defaults;
  final Future<String> Function(Map<String, String> values) onRun;

  const MethodTileWithForm({
    required this.name,
    required this.description,
    required this.fields,
    this.defaults = const {},
    required this.onRun,
  });

  @override
  State<MethodTileWithForm> createState() => _MethodTileWithFormState();
}

class _MethodTileWithFormState extends State<MethodTileWithForm> {
  bool _expanded = false;
  bool _loading = false;
  String? _result;
  bool _isError = false;
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in widget.fields)
        f: TextEditingController(text: widget.defaults[f] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run() async {
    final values = {
      for (final e in _controllers.entries) e.key: e.value.text.trim(),
    };
    for (final f in widget.fields) {
      if (values[f]?.isEmpty ?? true) {
        setState(() {
          _result = 'Missing required field: $f';
          _isError = true;
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });
    try {
      final r = await widget.onRun(values);
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
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontFamily: 'monospace', fontSize: 13)),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (_expanded) ...[
              const SizedBox(height: 8),
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextField(
                    controller: _controllers[f],
                    decoration: InputDecoration(
                      labelText: f,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                    obscureText: f.toLowerCase().contains('password'),
                    style:
                        const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
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
              ),
            ],
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
