import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

/// Opens Circle's hosted challenge UI in a bottom sheet WebView.
/// Circle calls back via URL scheme when the user approves or cancels.
class CircleWebView extends StatefulWidget {
  const CircleWebView({
    required this.challengeUrl,
    required this.onComplete,
    required this.onError,
    super.key,
  });

  final String challengeUrl;
  final VoidCallback onComplete;
  final ValueChanged<String> onError;

  static Future<void> show({
    required BuildContext context,
    required String challengeUrl,
    required VoidCallback onComplete,
    required ValueChanged<String> onError,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CircleWebView(
        challengeUrl: challengeUrl,
        onComplete: onComplete,
        onError: onError,
      ),
    );
  }

  @override
  State<CircleWebView> createState() => _CircleWebViewState();
}

class _CircleWebViewState extends State<CircleWebView> {
  late final WebViewController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (req) {
            final url = req.url;
            // Circle signals completion via URL scheme
            if (url.contains('circle-pw://') ||
                url.contains('challenge-complete') ||
                url.contains('success=true')) {
              Navigator.of(context).pop();
              widget.onComplete();
              return NavigationDecision.prevent;
            }
            if (url.contains('error=') || url.contains('cancelled=true')) {
              final uri = Uri.tryParse(url);
              final err = uri?.queryParameters['error'] ?? 'Challenge cancelled';
              Navigator.of(context).pop();
              widget.onError(err);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (err) {
            widget.onError(err.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.challengeUrl));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Text('Approve Transaction',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textSubtle),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onError('Cancelled by user');
                  },
                ),
              ],
            ),
          ),
          Divider(color: t.border, height: 1),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _ctrl),
                if (_loading)
                  Center(
                    child: CircularProgressIndicator(
                        color: t.brand, strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
