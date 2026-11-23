import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/name_page.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: NamePage(onContinue: (_) async {}),
    ),
  );
}
