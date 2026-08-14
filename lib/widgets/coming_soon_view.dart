import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ComingSoonView extends StatelessWidget {
  final String title;
  final String message;
  final bool showAppBar;
  final Widget? footer;

  const ComingSoonView({super.key, required this.title, required this.message, this.showAppBar = true, this.footer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: AppColors.card,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(title, style: AppFonts.display(size: 18)),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Icon(Icons.hourglass_top_outlined, size: 26, color: AppColors.accent),
                ),
                const SizedBox(height: 16),
                Text('Coming soon', style: AppFonts.display(size: 18)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: AppFonts.body(size: 13.5, color: AppColors.ink3).copyWith(height: 1.5)),
                if (footer != null) ...[const SizedBox(height: 22), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
