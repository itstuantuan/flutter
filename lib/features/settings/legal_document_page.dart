import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_widgets.dart';

/// The supplied policy is bundled verbatim so it is readable before login
/// and without a network connection.
class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.assetPath,
  });
  final String title, assetPath;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late Future<String> _content;

  @override
  void initState() {
    super.initState();
    _content = rootBundle.loadString(widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant LegalDocumentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _content = rootBundle.loadString(widget.assetPath);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: widget.title,
    child: FutureBuilder<String>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText('${widget.title}加载失败，请重试。'),
                TextButton(
                  onPressed: () => setState(() {
                    _content = rootBundle.loadString(widget.assetPath);
                  }),
                  child: const AppText('重试'),
                ),
              ],
            ),
          );
        }
        final text = snapshot.data;
        if (text == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final lines = text.split('\n');
        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: SelectableText.rich(
              TextSpan(
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 15,
                  height: 1.8,
                ),
                children: [
                  for (var i = 0; i < lines.length; i++)
                    TextSpan(
                      text: '${lines[i]}${i == lines.length - 1 ? '' : '\n\n'}',
                      style: i == 0
                          ? const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            )
                          : RegExp(r'^(?:[一二三四五六七八九十]+|[IVX]+)\s')
                                .hasMatch(lines[i])
                          ? const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )
                          : RegExp(r'^\d+\s').hasMatch(lines[i])
                          ? const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
