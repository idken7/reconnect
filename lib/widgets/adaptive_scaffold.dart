import 'package:flutter/material.dart';

/// A plain Material [Scaffold] with an [AppBar], styled by the app's single
/// [ThemeData] (see `lib/theme/reconnect_theme.dart`) on every platform —
/// the app deliberately reads the same on iOS and Android rather than
/// switching between Cupertino and Material chrome.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBackButton = true,
    this.trailing,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  final String title;
  final Widget body;
  final bool showBackButton;
  final Widget? trailing;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: showBackButton,
        actions: trailing == null
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(child: trailing!),
                ),
              ],
      ),
      body: SafeArea(top: false, bottom: true, child: body),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
