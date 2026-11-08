import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'widgets.dart';

/// Connects the app to Wise with a read-only API token.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key, this.replacing = false});

  /// True when changing the token from settings, rather than first-time setup.
  final bool replacing;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _token = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) setState(() => _token.text = text);
  }

  Future<void> _connect() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Paste your Wise token first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AppScope.read(context).connect(token);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null && widget.replacing) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.replacing ? AppBar(title: const Text('Change Wise token')) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.replacing) ...[
                    const Align(alignment: Alignment.centerLeft, child: AppMark(size: 56)),
                    const SizedBox(height: 24),
                    const Text('Connect Wise', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    'Paste a read-only API token so the app can read your MYR balance and transactions.',
                    style: Styles.body,
                  ),
                  const SizedBox(height: 20),
                  const _Step(1, 'Open wise.com and log in'),
                  const _Step(2, 'Go to Settings, then Integrations and tools, then API tokens'),
                  const _Step(3, 'Add a new token with Read only access'),
                  const _Step(4, 'Copy it and paste it below'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _token,
                    obscureText: _hidden,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _connect(),
                    style: const TextStyle(fontFeatures: tabular),
                    decoration: InputDecoration(
                      labelText: 'API token',
                      errorText: _error,
                      errorMaxLines: 4,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(tooltip: 'Paste', onPressed: _paste, icon: const Icon(Icons.content_paste)),
                          IconButton(
                            tooltip: _hidden ? 'Show token' : 'Hide token',
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Connect'),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: Palette.muted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Saved securely on this device. A read-only token can't move money.",
                          style: Styles.meta,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text('$number.', style: Styles.body.copyWith(color: Palette.muted)),
          ),
          Expanded(child: Text(text, style: Styles.body)),
        ],
      ),
    );
  }
}
