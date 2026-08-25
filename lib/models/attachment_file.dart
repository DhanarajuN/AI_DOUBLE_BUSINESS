import 'dart:typed_data';

class AttachmentFile {
  final String name;
  final String? url;
  final Uint8List? bytes;

  const AttachmentFile({required this.name, this.url, this.bytes});

  bool get isUploaded => url != null;

  factory AttachmentFile.fromJson(Map<String, dynamic> json) => AttachmentFile(
        name: (json['fileName'] as String?) ??
            (json['fileUrl'] as String?)?.split('/').last ??
            'File',
        url: json['fileUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {'fileUrl': url, 'fileName': name};
}
