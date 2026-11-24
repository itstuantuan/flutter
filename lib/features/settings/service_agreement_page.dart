import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import 'legal_document_page.dart';

class ServiceAgreementPage extends StatelessWidget {
  const ServiceAgreementPage({super.key});

  @override
  Widget build(BuildContext context) => LegalDocumentPage(
    title: '服务协议',
    assetPath:
        'assets/legal/service_agreement_${isEnglish(context) ? 'en' : 'zh'}.txt',
  );
}
