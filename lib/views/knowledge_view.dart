import 'package:flutter/material.dart';
import '../widgets/coming_soon_view.dart';

class KnowledgeView extends StatelessWidget {
  const KnowledgeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonView(
      title: 'Your documents',
      message: 'Uploading and managing knowledge sources for the assistant is still in progress.',
    );
  }
}
