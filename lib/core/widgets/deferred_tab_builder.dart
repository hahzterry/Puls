import 'package:flutter/material.dart';

/// A utility to build UI from deferred imported libraries.
/// Automatically triggers the loadLibrary function and shows a loader.
class DeferredTabBuilder extends StatefulWidget {
  const DeferredTabBuilder({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;

  @override
  State<DeferredTabBuilder> createState() => _DeferredTabBuilderState();
}

class _DeferredTabBuilderState extends State<DeferredTabBuilder> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await widget.loadLibrary();
      if (mounted) {
        setState(() => _loaded = true);
      }
    } catch (e) {
      debugPrint('Failed to load deferred library: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2DD4BF)),
      );
    }
    return widget.builder(context);
  }
}
