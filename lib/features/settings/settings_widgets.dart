import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

const settingsBackground = Color(0xFF33303B);
const settingsMuted = Color(0xFF9CA3AF);
const settingsGradient = LinearGradient(
  colors: [Color(0xFF2EA5EF), Color(0xFFA43ADD)],
);

Widget settingsIcon(String name, double size) =>
    SvgPicture.asset('assets/sidebar/$name.svg', width: size, height: size);

class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        textTheme: Theme.of(context).textTheme
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: settingsMuted, fontSize: 13),
        ),
      ),
      child: Scaffold(
        backgroundColor: settingsBackground,
        appBar: AppBar(
          backgroundColor: settingsBackground,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: true,
          toolbarHeight: 48,
          title: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.maybePop(context),
            icon: settingsIcon('back', 24),
          ),
          actions: actions,
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<String?> showSettingsChoices(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
  bool grouped = false,
}) => showModalBottomSheet<String>(
  context: context,
  backgroundColor: const Color(0xFF474451),
  isScrollControlled: true,
  barrierColor: Colors.black.withValues(alpha: .4),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            SizedBox(
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: '关闭',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: Opacity(
                          opacity: .46,
                          child: settingsIcon('close', 8.625),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              padding: EdgeInsets.symmetric(horizontal: grouped ? 16 : 4),
              decoration: BoxDecoration(
                color: grouped ? Colors.white.withValues(alpha: .06) : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (final (index, option) in options.indexed)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, option),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          decoration: BoxDecoration(
                            border: index < options.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: .08,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: selected == option
                                    ? ShaderMask(
                                        shaderCallback: (rect) =>
                                            const LinearGradient(
                                              colors: [
                                                Color(0xFFA8FEFF),
                                                Color(0xFFC869FF),
                                              ],
                                            ).createShader(rect),
                                        child: Text(
                                          option,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        option,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                              if (selected == option)
                                settingsIcon('check', 24)
                              else if (grouped)
                                settingsIcon('profile_chevron', 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class SettingsGradientButton extends StatelessWidget {
  const SettingsGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: settingsGradient,
      borderRadius: BorderRadius.circular(104),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(104),
        onTap: onPressed,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
