import 'package:flutter/material.dart';

import 'legal_document_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocumentPage(
    title: '隐私政策',
    assetPath: 'assets/legal/privacy_policy_zh.txt',
  );
}
