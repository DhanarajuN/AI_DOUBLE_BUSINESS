import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/server_urls.dart';
import '../models/doc_source.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../viewmodels/knowledge_view_model.dart';
import '../widgets/business_icons.dart';

class KnowledgeView extends StatelessWidget {
  const KnowledgeView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => DashboardViewModel(
              ctx.read<WorkspaceRepository>(), ctx.read<SessionStorage>(), ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => KnowledgeViewModel(ctx.read<WorkspaceRepository>()),
        ),
      ],
      child: const _KnowledgeHub(),
    );
  }
}

class _KnowledgeHub extends StatelessWidget {
  const _KnowledgeHub();

  @override
  Widget build(BuildContext context) {
    context.watch<WorkspaceRepository>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.paper2,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.ink,
          title: Text('Knowledge', style: AppFonts.display(size: 17)),
          bottom: TabBar(
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.ink3,
            indicatorColor: AppColors.accent,
            labelStyle: AppFonts.body(size: 13, weight: FontWeight.w600),
            unselectedLabelStyle: AppFonts.body(size: 13, weight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Services'),
              Tab(text: 'Providers'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _CategoryTab(
                category: kDocCategoryProduct,
                categoryLabel: 'product',
                categoryPlural: 'Products',
                icon: Icons.inventory_2_outlined,
                titleKeys: const ['Product Name', 'Name', 'Title'],
                subtitleKeys: const ['Product Category', 'Category', 'AI Description', 'Description'],
                priceKeys: const ['Price', 'Amount'],
                emptyTitle: 'No products yet',
                emptyText: 'Products your business offers will show up here.',
                items: (vm) => vm.products,
                hasMore: (vm) => vm.productsHasMore,
                loadingMore: (vm) => vm.productsLoadingMore,
                loadMore: (vm) => vm.loadMoreProducts(),
              ),
              _CategoryTab(
                category: kDocCategoryService,
                categoryLabel: 'service',
                categoryPlural: 'Services',
                icon: Icons.design_services_outlined,
                titleKeys: const ['Service Name', 'Name', 'Title'],
                subtitleKeys: const ['Service Category', 'Category', 'Duration', 'AI Description', 'Description'],
                priceKeys: const ['Price', 'Amount'],
                emptyTitle: 'No services yet',
                emptyText: 'Services your business offers will show up here.',
                items: (vm) => vm.services,
                hasMore: (vm) => vm.servicesHasMore,
                loadingMore: (vm) => vm.servicesLoadingMore,
                loadMore: (vm) => vm.loadMoreServices(),
              ),
              _CategoryTab(
                category: kDocCategoryProvider,
                categoryLabel: 'provider',
                categoryPlural: 'Providers',
                icon: Icons.badge_outlined,
                titleKeys: const ['Provider Name', 'Name', 'Full Name'],
                subtitleKeys: const ['Specialization', 'Role', 'Specialty', 'Description', 'AI Description'],
                priceKeys: const ['Phone Number', 'Phone', 'Availability'],
                emptyTitle: 'No providers yet',
                emptyText: 'People who fulfil orders and services will show up here.',
                items: (vm) => vm.providers,
                hasMore: (vm) => vm.providersHasMore,
                loadingMore: (vm) => vm.providersLoadingMore,
                loadMore: (vm) => vm.loadMoreProviders(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  final String category;
  final String categoryLabel;
  final String categoryPlural;
  final IconData icon;
  final List<String> titleKeys;
  final List<String> subtitleKeys;
  final List<String> priceKeys;
  final String emptyTitle;
  final String emptyText;
  final List<Map<String, dynamic>> Function(DashboardViewModel vm) items;
  final bool Function(DashboardViewModel vm) hasMore;
  final bool Function(DashboardViewModel vm) loadingMore;
  final Future<void> Function(DashboardViewModel vm) loadMore;

  const _CategoryTab({
    required this.category,
    required this.categoryLabel,
    required this.categoryPlural,
    required this.icon,
    required this.titleKeys,
    required this.subtitleKeys,
    required this.priceKeys,
    required this.emptyTitle,
    required this.emptyText,
    required this.items,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMore,
  });

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> with AutomaticKeepAliveClientMixin {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isPaste = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels < _scrollCtrl.position.maxScrollExtent - 200) return;
    final vm = context.read<DashboardViewModel>();
    if (widget.hasMore(vm) && !widget.loadingMore(vm)) widget.loadMore(vm);
  }

  Future<void> _addText(KnowledgeViewModel vm) async {
    final error = await vm.addText(_titleCtrl.text, _textCtrl.text, category: widget.category);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), behavior: SnackBarBehavior.floating));
      return;
    }
    _titleCtrl.clear();
    _textCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document added'), behavior: SnackBarBehavior.floating));
  }

  Future<void> _pickFile(KnowledgeViewModel vm) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'csv', 'json', 'log'],
    );
    if (result == null || !mounted) return;
    final files = [
      for (final f in result.files)
        if (f.bytes != null) (f.name, f.bytes!, f.size),
    ];
    final warnings = await vm.addPickedFiles(files, category: widget.category);
    if (!mounted) return;
    for (final w in warnings) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(w), behavior: SnackBarBehavior.floating));
    }
    if (warnings.length < files.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document added'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dashVm = context.watch<DashboardViewModel>();
    final knowledgeVm = context.watch<KnowledgeViewModel>();
    final items = widget.items(dashVm);
    final categoryDocs = knowledgeVm.docs.where((d) => d.category == widget.category).toList();

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _uploadCard(knowledgeVm),
        if (categoryDocs.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('${widget.categoryPlural} documents', style: AppFonts.display(size: 15)),
          const SizedBox(height: 10),
          ...categoryDocs.map((d) => _docRow(knowledgeVm, d)),
        ],
        const SizedBox(height: 20),
        Text(widget.categoryPlural, style: AppFonts.display(size: 17)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _emptyState()
        else ...[
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _categoryCard(context, item),
              )),
          if (widget.loadingMore(dashVm))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ],
    );
  }

  Widget _uploadCard(KnowledgeViewModel vm) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.upload_outlined, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Upload a ${widget.categoryLabel} document', style: AppFonts.body(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: AppColors.paper2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(child: _modeTab('Paste text', _isPaste, () => setState(() => _isPaste = true))),
                Expanded(child: _modeTab('Upload file', !_isPaste, () => setState(() => _isPaste = false))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_isPaste) ...[
            TextField(
              controller: _titleCtrl,
              style: AppFonts.body(size: 13.5, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Title (e.g. ${widget.categoryPlural} price list)',
                hintStyle: AppFonts.body(size: 13, color: AppColors.ink3),
                filled: true,
                fillColor: AppColors.paper2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textCtrl,
              maxLines: 4,
              style: AppFonts.body(size: 13, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Paste details about your ${widget.categoryLabel}s here.',
                hintStyle: AppFonts.body(size: 13, color: AppColors.ink3),
                filled: true,
                fillColor: AppColors.paper2,
                contentPadding: const EdgeInsets.all(12),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                ),
                onPressed: () => _addText(vm),
                icon: const Icon(Icons.check, size: 17),
                label: const Text('Add document', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ] else
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: vm.picking ? null : () => _pickFile(vm),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.paper2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line2, width: 1.2),
                ),
                child: Column(
                  children: [
                    vm.picking
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                        : Icon(Icons.upload_file_outlined, color: AppColors.accent, size: 20),
                    const SizedBox(height: 8),
                    Text('Tap to browse for a file', style: AppFonts.body(size: 13, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text('txt · md · csv · json · log', style: AppFonts.mono(size: 10, color: AppColors.ink3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool on, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? AppColors.card : null, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: AppFonts.body(size: 12, weight: FontWeight.w600, color: on ? AppColors.ink : AppColors.ink2)),
        ),
      );

  Widget _docRow(KnowledgeViewModel vm, DocSource d) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Icon(businessIcon(d.isFile ? 'file' : 'doc'), size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                  Text(d.meta, style: AppFonts.body(size: 11, color: AppColors.ink3)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => vm.removeDoc(d.id),
              icon: Icon(Icons.delete_outline, color: AppColors.ink3, size: 19),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
          ],
        ),
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
        child: Column(
          children: [
            Icon(widget.icon, size: 24, color: AppColors.accent),
            const SizedBox(height: 10),
            Text(widget.emptyTitle, style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(widget.emptyText, textAlign: TextAlign.center, style: AppFonts.body(size: 12.5, color: AppColors.ink3)),
          ],
        ),
      );

  Widget _categoryAvatar(BuildContext context, Map<String, dynamic> data, {required double size, required double iconSize}) {
    final imageUrl = _firstImageUrl(data);
    final fallback = Icon(widget.icon, size: iconSize, color: AppColors.accent);
    final apiClient = context.read<ApiClient>();
    final avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: imageUrl == null
          ? fallback
          : Image.network(
              ServerUrls.s3ObjectDownloadUrl(imageUrl),
              headers: _imageHeaders(apiClient),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      width: size * 0.5,
                      height: size * 0.5,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
            ),
    );

    if (imageUrl == null) return avatar;
    return InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: () => _openImageViewer(
          context, ServerUrls.s3ObjectDownloadUrl(imageUrl), _imageHeaders(apiClient)),
      child: avatar,
    );
  }

  Widget _categoryCard(BuildContext context, Map<String, dynamic> item) {
    final data = _itemData(item);
    final title = _firstNonEmptyField(data, widget.titleKeys) ?? 'Untitled';
    final subtitle = _firstNonEmptyField(data, widget.subtitleKeys);
    final price = _firstNonEmptyField(data, widget.priceKeys);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showCategoryDetail(context, item, title),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            _categoryAvatar(context, data, size: 40, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (price != null)
              Text(price, style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.accent)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }

  void _showCategoryDetail(BuildContext context, Map<String, dynamic> item, String title) {
    final data = _itemData(item);
    final fields = data.entries
        .where((e) => !widget.titleKeys.any((k) => k.toLowerCase() == e.key.toLowerCase()))
        .where((e) => e.value is String || e.value is num || e.value is bool)
        .where((e) => e.value.toString().trim().isNotEmpty)
        .take(10)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(100)),
                  ),
                ),
                Row(
                  children: [
                    _categoryAvatar(context, data, size: 44, iconSize: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: AppFonts.display(size: 17))),
                  ],
                ),
                const SizedBox(height: 20),
                if (fields.isEmpty)
                  _detailRow(Icons.info_outline, 'Details', 'No additional details available.')
                else
                  ...fields.map((e) => _detailRow(Icons.info_outline, _humanizeKey(e.key), e.value.toString())),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.line2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Close', style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _openImageViewer(BuildContext context, String url, Map<String, String> headers) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  headers: headers,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> _itemData(Map<String, dynamic> item) =>
    item['data'] is Map ? Map<String, dynamic>.from(item['data'] as Map) : <String, dynamic>{};

String? _firstImageUrl(Map<String, dynamic> data) {
  dynamic search(dynamic node) {
    if (node is Map) {
      final url = node['fileUrl'];
      if (url is String && url.trim().isNotEmpty) return url.trim();
      return null;
    }
    if (node is List) {
      for (final child in node) {
        final found = search(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  return search(data['Image']) as String?;
}

Map<String, String> _imageHeaders(ApiClient apiClient) => {
      if (apiClient.tenant != null) 'X-Tenant': apiClient.tenant!,
      if ((apiClient.accessToken ?? '').isNotEmpty) 'Authorization': 'Bearer ${apiClient.accessToken}',
    };

String? _firstNonEmptyField(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _humanizeKey(String key) {
  if (key.contains(' ')) return key;
  final spaced = key.replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (m) => ' ');
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

Widget _detailRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.body(size: 11, color: AppColors.ink3)),
                const SizedBox(height: 2),
                Text(value, style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
