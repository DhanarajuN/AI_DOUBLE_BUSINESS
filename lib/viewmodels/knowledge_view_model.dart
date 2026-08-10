import 'package:flutter/foundation.dart';
import '../models/doc_source.dart';
import '../repositories/workspace_repository.dart';

enum KnowledgeSourceMode { paste, upload }

class KnowledgeViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;

  KnowledgeViewModel(this._workspace) {
    _workspace.addListener(notifyListeners);
  }

  KnowledgeSourceMode _mode = KnowledgeSourceMode.paste;
  KnowledgeSourceMode get mode => _mode;

  bool _picking = false;
  bool get picking => _picking;

  List<DocSource> get docs => _workspace.docs;
  bool get keyReady => _workspace.keyReady;

  void setMode(KnowledgeSourceMode m) {
    _mode = m;
    notifyListeners();
  }

  Future<String?> addText(String title, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Paste some text first';
    await _workspace.addTextDoc(title.trim().isEmpty ? 'Note ${docs.length + 1}' : title.trim(), trimmed);
    return null;
  }

  Future<List<String>> addPickedFiles(List<(String name, Uint8List bytes, int size)> files) async {
    _picking = true;
    notifyListeners();
    final warnings = <String>[];
    try {
      for (final (name, bytes, size) in files) {
        if (size > 2 * 1024 * 1024) {
          warnings.add('$name is over 2 MB');
          continue;
        }
        String text;
        try {
          text = String.fromCharCodes(bytes);
        } catch (_) {
          warnings.add('$name could not be read as text');
          continue;
        }
        await _workspace.addFileDoc(name, text, '${(size / 1024).toStringAsFixed(0)} KB');
      }
    } finally {
      _picking = false;
      notifyListeners();
    }
    return warnings;
  }

  Future<void> removeDoc(String id) => _workspace.removeDoc(id);

  Future<void> clearDocs() => _workspace.clearDocs();

  @override
  void dispose() {
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
