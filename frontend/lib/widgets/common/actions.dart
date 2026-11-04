import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void showToast(
  BuildContext context,
  String message, {
  bool error = false,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: error
            ? const Color(0xFF8B1E24)
            : const Color(0xFF1E293B),
        action: action,
        duration: Duration(seconds: action != null ? 8 : 4),
        width: MediaQuery.sizeOf(context).width > 640 ? 520 : null,
      ),
    );
}

Future<void> openLink(BuildContext context, Uri uri) async {
  final ok = await launchUrl(
    uri,
    webOnlyWindowName: uri.scheme.startsWith('http') ? '_blank' : '_self',
  );
  if (!ok && context.mounted) {
    showToast(context, 'Could not open $uri', error: true);
  }
}

Future<void> copyToClipboard(
  BuildContext context,
  String text,
  String toast,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, toast);
}

Uri mailto(String email, {String? subject, String? body}) => Uri(
  scheme: 'mailto',
  path: email,
  query: _encodeQuery({'subject': ?subject, 'body': ?body}),
);

// Uri(queryParameters:) encodes spaces as '+', which mail clients show
// literally, so encode with %20 instead.
String? _encodeQuery(Map<String, String> params) => params.isEmpty
    ? null
    : params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
