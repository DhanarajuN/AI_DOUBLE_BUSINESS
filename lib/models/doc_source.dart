class DocSource {
  final String id;
  final String name;
  final String text;
  final String meta;
  final bool isFile;

  const DocSource({
    required this.id,
    required this.name,
    required this.text,
    required this.meta,
    this.isFile = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'text': text,
        'meta': meta,
        'isFile': isFile,
      };

  factory DocSource.fromJson(Map<String, dynamic> json) => DocSource(
        id: json['id'] as String,
        name: json['name'] as String,
        text: json['text'] as String,
        meta: json['meta'] as String? ?? '',
        isFile: json['isFile'] as bool? ?? false,
      );
}
