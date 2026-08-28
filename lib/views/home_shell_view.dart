import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../theme/app_theme.dart';
import 'account_view.dart';
import 'business_conversations_view.dart';
import 'calendar_view.dart';
import 'dashboard_view.dart';
import 'knowledge_view.dart';
import 'orders_view.dart';

class HomeShellView extends StatefulWidget {
  const HomeShellView({super.key});

  @override
  State<HomeShellView> createState() => _HomeShellViewState();
}

class _HomeShellViewState extends State<HomeShellView> {
  int _index = 0;

  static const _allTabs = [
    (
      icon: Icons.home_outlined,
      iconOn: Icons.home,
      label: 'Home',
      page: DashboardView(),
    ),
    (
      icon: Icons.calendar_month_outlined,
      iconOn: Icons.calendar_month,
      label: 'Calendar',
      page: CalendarView(),
    ),
    (
      icon: Icons.shopping_bag_outlined,
      iconOn: Icons.shopping_bag,
      label: 'Orders',
      page: OrdersView(),
    ),
    (
      icon: Icons.chat_bubble_outline,
      iconOn: Icons.chat_bubble,
      label: 'Chats',
      page: BusinessConversationsView(),
    ),
    (
      icon: Icons.description_outlined,
      iconOn: Icons.description,
      label: 'Knowledge',
      page: KnowledgeView(),
    ),
    (
      icon: Icons.person_outline,
      iconOn: Icons.person,
      label: 'Account',
      page: AccountView(),
    ),
  ];

  // AIDOUBLE_BROKER_HIDE_ITEMS / AIDOUBLE_BUSINESS_HIDE_ITEMS (from
  // /api/v1/module-constants, fetched at login, role-scoped in
  // AuthRepository.hideItems) name tabs — by their label above — that the
  // signed-in role should not see at all, e.g. "Knowledge" or "Orders".
  List<({IconData icon, IconData iconOn, String label, Widget page})> _visibleTabs(BuildContext context) {
    final hide = (context.watch<AuthRepository>().hideItems ?? const <String>[])
        .map((s) => s.trim().toLowerCase())
        .toSet();
    if (hide.isEmpty) return _allTabs;
    return _allTabs.where((t) => !hide.contains(t.label.toLowerCase())).toList();
  }

  void goToTab(String label) {
    final tabs = _visibleTabs(context);
    final i = tabs.indexWhere((t) => t.label == label);
    if (i != -1) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<WorkspaceRepository>();
    final tabs = _visibleTabs(context);
    final index = _index.clamp(0, tabs.length - 1);
    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: IndexedStack(index: index, children: tabs.map((t) => t.page).toList()),
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
              children: List.generate(tabs.length, (i) {
                final t = tabs[i];
                final on = i == index;
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
