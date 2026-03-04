import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:auth0_flutter_auth/src/jwt/jwt_decoder.dart';

class TokenCard extends StatefulWidget {
  final String title;
  final String token;
  const TokenCard({required this.title, required this.token, super.key});

  @override
  State<TokenCard> createState() => _TokenCardState();
}

class _TokenCardState extends State<TokenCard> {
  bool _showDecoded = false;
  Map<String, dynamic>? _header;
  Map<String, dynamic>? _payload;
  String? _decodeError;

  @override
  void initState() {
    super.initState();
    try {
      final jwt = JwtDecoder(widget.token);
      _header = jwt.header;
      _payload = jwt.payload;
    } catch (e) {
      _decodeError = e.toString();
    }
  }

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
            color: cs.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.token, size: 18, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: cs.onPrimaryContainer)),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.token));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${widget.title} copied'),
                        duration: const Duration(seconds: 1)));
                  },
                  tooltip: 'Copy raw token',
                  visualDensity: VisualDensity.compact,
                  color: cs.onPrimaryContainer,
                ),
                IconButton(
                  icon: Icon(_showDecoded ? Icons.code_off : Icons.code,
                      size: 18),
                  onPressed: () =>
                      setState(() => _showDecoded = !_showDecoded),
                  tooltip: _showDecoded ? 'Show raw' : 'Show decoded',
                  visualDensity: VisualDensity.compact,
                  color: cs.onPrimaryContainer,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _showDecoded ? _buildDecoded() : _buildRaw(),
          ),
        ],
      ),
    );
  }

  Widget _buildRaw() {
    return SelectableText(widget.token,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        maxLines: 6);
  }

  Widget _buildDecoded() {
    if (_decodeError != null) {
      return Text('Decode error: $_decodeError',
          style: TextStyle(color: Theme.of(context).colorScheme.error));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _decodedSection('Header', _header!),
        const SizedBox(height: 12),
        _decodedSection('Payload', _payload!),
      ],
    );
  }

  Widget _decodedSection(String label, Map<String, dynamic> data) {
    final formatted =
        const JsonEncoder.withIndent('  ').convert(_formatClaims(data));
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: formatted));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$label copied'),
                    duration: const Duration(seconds: 1)));
              },
              child:
                  Icon(Icons.copy, size: 14, color: theme.colorScheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(formatted,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.colorScheme.onSurface)),
        ),
      ],
    );
  }

  Map<String, dynamic> _formatClaims(Map<String, dynamic> claims) {
    const epochKeys = {'iat', 'exp', 'auth_time', 'nbf', 'updated_at'};
    return {
      for (final e in claims.entries)
        e.key: epochKeys.contains(e.key) && e.value is int
            ? '${e.value}  (${DateTime.fromMillisecondsSinceEpoch(e.value * 1000).toLocal()})'
            : e.value,
    };
  }
}
