import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/workspace_repository.dart';
import '../theme/app_theme.dart';
import 'account_view.dart';
import 'business_conversations_view.dart';
import 'calendar_view.dart';
import 'dashboard_view.dart';
import 'knowledge_view.dart';

class HomeShellView extends StatefulWidget {
  const HomeShellView({super.key});

  @override
  State<HomeShellView> createState() => _HomeShellViewState();
}

class _HomeShellViewState extends State<HomeShellView> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home_outlined, iconOn: Icons.home, label: 'Home'),
    (
      icon: Icons.calendar_month_outlined,
      iconOn: Icons.calendar_month,
      label: 'Calendar'
    ),
    (
      icon: Icons.chat_bubble_outline,
      iconOn: Icons.chat_bubble,
      label: 'Chats'
    ),
    (
      icon: Icons.description_outlined,
      iconOn: Icons.description,
      label: 'Docs'
    ),
    (icon: Icons.person_outline, iconOn: Icons.person, label: 'Account'),
  ];

  final _pages = const [
    DashboardView(),
    CalendarView(),
    BusinessConversationsView(),
    KnowledgeView(),
    AccountView(),
  ];

  void goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    context.watch<WorkspaceRepository>();
    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.line)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A0F1B2E), blurRadius: 14, offset: Offset(0, -2))
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i];
                final on = i == _index;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(on ? t.iconOn : t.icon,
                            size: 23,
                            color: on ? AppColors.accent : AppColors.ink3),
                        const SizedBox(height: 3),
                        Text(
                          t.label,
                          style: AppFonts.body(
                              size: 10.5,
                              weight: FontWeight.w600,
                              color: on ? AppColors.accent : AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
