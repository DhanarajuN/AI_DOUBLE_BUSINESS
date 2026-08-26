import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../constants/server_urls.dart';
import '../models/attachment_file.dart';
import '../models/job_type_schema.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/friendly_error.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart' show fmtDateDMY, fmtDateTimeDMY, fmtTimeOnly;
import 'searchable_options_picker.dart';

// "#" in the mask is a placeholder consumed by the next raw input character
// in order; anything else in the mask is a literal inserted automatically.
// e.g. mask "###-##-####" + input "123456789" -> "123-45-6789".
String applyMask(String mask, String rawInput) {
  final chars = rawInput.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
  final buffer = StringBuffer();
  var ci = 0;
  for (var i = 0; i < mask.length && ci < chars.length; i++) {
    if (mask[i] == '#') {
      buffer.write(chars[ci]);
      ci++;
    } else {
      buffer.write(mask[i]);
    }
  }
  return buffer.toString();
}

String groupThousands(String digits) => digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

class MaskedValue {
  final String rawInput;
  final String formattedValue;
  const MaskedValue(this.rawInput, this.formattedValue);
}

MaskedValue getMaskedValue(String fieldValue, String maskConfig) {
  if (maskConfig.isEmpty) return MaskedValue(fieldValue, fieldValue);

  var prefix = '';
  var suffix = '';
  var maskPattern = maskConfig;
  var maskType = '';

  if (maskConfig.trim().startsWith('{')) {
    try {
      final decoded = jsonDecode(maskConfig);
      if (decoded is Map) {
        prefix = decoded['prefix']?.toString() ?? '';
        suffix = decoded['suffix']?.toString() ?? '';
        maskPattern = decoded['maskPattern']?.toString() ?? '';
        maskType = decoded['mask']?.toString() ?? '';
      }
    } catch (_) {
      maskPattern = maskConfig;
    }
  }

  var rawInput = prefix.isNotEmpty ? fieldValue.replaceFirst(prefix, '') : fieldValue;
  rawInput = maskPattern.isNotEmpty && maskType.isEmpty
      ? rawInput.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')
      : rawInput.replaceAll(RegExp(r'[^0-9.]'), '');

  if (rawInput.isEmpty) return const MaskedValue('', '');

  final formattedValue = maskPattern.isNotEmpty
      ? '$prefix${applyMask(maskPattern, rawInput)}$suffix'
      : '$prefix${groupThousands(rawInput)}$suffix';

  return MaskedValue(rawInput, formattedValue);
}

String maskHint(String maskConfig) {
  if (!maskConfig.trim().startsWith('{')) return maskConfig;
  try {
    final decoded = jsonDecode(maskConfig);
    if (decoded is Map) return decoded['maskPattern']?.toString() ?? '';
  } catch (_) {}
  return '';
}

class MaskTextInputFormatter extends TextInputFormatter {
  final String maskConfig;
  const MaskTextInputFormatter(this.maskConfig);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final result = getMaskedValue(newValue.text, maskConfig);
    final formatted = result.formattedValue;
    final caret = newValue.selection.end.clamp(0, newValue.text.length);
    final rawBeforeCaret =
        newValue.text.substring(0, caret).replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').length;

    var offset = formatted.length;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9a-zA-Z]').hasMatch(formatted[i])) {
        seen++;
        if (seen >= rawBeforeCaret) {
          offset = i + 1;
          while (offset < formatted.length && !RegExp(r'[0-9a-zA-Z]').hasMatch(formatted[offset])) {
            offset++;
          }
          break;
        }
      }
    }
    if (rawBeforeCaret == 0) offset = 0;

    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: offset));
  }
}

bool _isValidPercent(String rule, String value) {
  final clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
  if (clean.isEmpty) return false;
  final val = double.tryParse(clean);
  if (val == null) return false;
  final match = RegExp(r'(?:Percentage|PERCENT):(\d+)-(\d+)').firstMatch(rule);
  if (match == null) return false;
  return val >= double.parse(match.group(1)!) && val <= double.parse(match.group(2)!);
}

class JobTypeFieldsForm extends StatelessWidget {
  final List<JobTypeField> fields;
  final dynamic Function(String fieldName) valueOf;
  final List<JobTypeFieldOption> Function(JobTypeField field) optionsFor;
  final void Function(String fieldName, String value) onTextChanged;
  final void Function(JobTypeField field, JobTypeFieldOption option) onPickSingle;
  final void Function(JobTypeField field, JobTypeFieldOption option) onToggleMulti;
  final Future<AttachmentFile> Function(String fileName, Uint8List bytes) onUploadFile;
  final void Function(JobTypeField field, List<AttachmentFile> files) onAttachmentsAdded;
  final void Function(JobTypeField field, AttachmentFile file) onAttachmentRemoved;

  const JobTypeFieldsForm({
    super.key,
    required this.fields,
    required this.valueOf,
    required this.optionsFor,
    required this.onTextChanged,
    required this.onPickSingle,
    required this.onToggleMulti,
    required this.onUploadFile,
    required this.onAttachmentsAdded,
    required this.onAttachmentRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.map((f) => _fieldWidget(context, f)).toList(),
    );
  }

  Widget _fieldWidget(BuildContext context, JobTypeField field) {
    if (field.isReadOnlyAuto) return _readOnlyField(field);
    if (field.isSelection) return _selectionField(context, field);
    if (field.isRadioOrCheckbox) return _radioOrCheckboxField(field);
    if (field.isBoolean) return _booleanField(field);
    if (field.isFile) return _attachmentField(context, field);
    if (field.isHtmlText) return _htmlField(field);
    if (field.isDatePicker || field.isTimePicker) {
      final raw = valueOf(field.name)?.toString() ?? '';
      // A UTC/offset value must be converted before it's used as the date
      // and time pickers' initialDate/initialTime — those read wall-clock
      // fields directly, and Flutter's date picker also rejects a
      // UTC-flagged initialDate outright.
      return _dateField(context, field, DateTime.tryParse(raw)?.toLocal());
    }
    if (field.hasPercentRule) return _PercentTextField(field: field, valueOf: valueOf, onTextChanged: onTextChanged);
    if (field.mask.isNotEmpty) return _MaskedTextField(field: field, valueOf: valueOf, onTextChanged: onTextChanged);
    return _dynamicTextField(field);
  }

  Widget _htmlField(JobTypeField field) {
    var htmlData = field.defaultValue;
    if (htmlData.contains('<body')) {
      final bodyStart = htmlData.indexOf('<body');
      final bodyEnd = htmlData.indexOf('</body>');
      if (bodyStart != -1 && bodyEnd != -1) {
        htmlData = htmlData.substring(htmlData.indexOf('>', bodyStart) + 1, bodyEnd);
      }
    }
    return Padding(
      key: ValueKey(field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          const SizedBox(height: 7),
          Html(data: htmlData),
        ],
      ),
    );
  }

  Widget _readOnlyField(JobTypeField field) {
    final raw = valueOf(field.name)?.toString() ?? '';
    final asDate = RegExp(r'^\d+$').hasMatch(raw) ? null : DateTime.tryParse(raw);
    final display = asDate != null ? (field.isAutoDateTime ? fmtDateTimeDMY(asDate) : fmtDateDMY(asDate)) : raw;
    return Padding(
      key: ValueKey(field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.paper2,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.line2),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(display.isEmpty ? '—' : display, style: AppFonts.body(size: 14.5, color: AppColors.ink3))),
                  Icon(Icons.lock_outline, size: 15, color: AppColors.ink3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _booleanField(JobTypeField field) {
    final raw = valueOf(field.name)?.toString();
    final value = raw == 'true' ? true : (raw == 'false' ? false : null);
    return Padding(
      key: ValueKey(field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => onTextChanged(field.name, value == null ? 'true' : (value ? 'false' : 'true')),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: value == true ? AppColors.ok : value == false ? AppColors.danger : AppColors.line2),
            borderRadius: BorderRadius.circular(11),
            color: AppColors.card,
          ),
          child: Row(
            children: [
              Icon(
                value == true ? Icons.check_box : value == false ? Icons.indeterminate_check_box : Icons.check_box_outline_blank,
                size: 20,
                color: value == true ? AppColors.ok : value == false ? AppColors.danger : AppColors.ink3,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(field.label, style: AppFonts.body(size: 14.5, color: AppColors.ink))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioOrCheckboxField(JobTypeField field) {
    final options = optionsFor(field);
    final selected = field.multiselect
        ? (valueOf(field.name) as Set<String>?) ?? const <String>{}
        : {if (valueOf(field.name) != null) valueOf(field.name) as String};
    return Padding(
      key: ValueKey(field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          ...options.map((o) {
            final on = selected.contains(o.submissionValue);
            return InkWell(
              onTap: () => field.multiselect ? onToggleMulti(field, o) : onPickSingle(field, o),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      field.multiselect
                          ? (on ? Icons.check_box : Icons.check_box_outline_blank)
                          : (on ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                      size: 20,
                      color: on ? AppColors.accent : AppColors.ink3,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(o.label, style: AppFonts.body(size: 14, color: AppColors.ink))),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _attachmentField(BuildContext context, JobTypeField field) {
    final files = (valueOf(field.name) as List<AttachmentFile>?) ?? const [];
    return Padding(
      key: ValueKey(field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => _pickAndUpload(context, field),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line2),
                  borderRadius: BorderRadius.circular(11),
                  color: AppColors.card,
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Attach ${field.label}', style: AppFonts.body(size: 14, color: AppColors.ink3))),
                  ],
                ),
              ),
            ),
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...files.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.paper2, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(f.isUploaded ? Icons.insert_drive_file_outlined : Icons.error_outline,
                            size: 16, color: f.isUploaded ? AppColors.ink3 : AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 13, color: AppColors.ink)),
                        ),
                        if (!f.isUploaded)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text('not uploaded', style: AppFonts.body(size: 10.5, color: AppColors.danger)),
                          ),
                        if (f.isUploaded)
                          InkWell(
                            onTap: () => _downloadFile(context, f),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Icon(Icons.download_outlined, size: 16, color: AppColors.ink3),
                            ),
                          ),
                        InkWell(
                          onTap: () => onAttachmentRemoved(field, f),
                          child: Icon(Icons.close, size: 16, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, JobTypeField field) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null) return;
    for (final picked in result.files) {
      final bytes = picked.bytes;
      if (bytes == null) continue;
      try {
        final uploaded = await onUploadFile(picked.name, bytes);
        onAttachmentsAdded(field, [uploaded]);
      } catch (e, st) {
        AppLogger.e('JobTypeFieldsForm', 'Could not upload ${picked.name}', e, st);
        onAttachmentsAdded(field, [AttachmentFile(name: picked.name)]);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not upload ${picked.name}: ${friendlyError(e)}'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Map<String, String> _authHeaders(ApiClient apiClient) => {
        if (apiClient.tenant != null) 'X-Tenant': apiClient.tenant!,
        if ((apiClient.accessToken ?? '').isNotEmpty) 'Authorization': 'Bearer ${apiClient.accessToken}',
      };

  String _cleanContentDispositionFileName(String raw) {
    var name = raw.trim().replaceAll('"', '');
    final charsetPrefix = RegExp(r"^[\w-]+''");
    if (charsetPrefix.hasMatch(name)) {
      name = Uri.decodeComponent(name.replaceFirst(charsetPrefix, ''));
    }
    return name;
  }

  Future<({Uint8List bytes, String fileName})> _fetchAttachment(BuildContext context, AttachmentFile f) async {
    final rawUrl = f.url;
    if (rawUrl == null) throw Exception('No file URL for ${f.name}');
    final apiClient = context.read<ApiClient>();
    final uri = Uri.parse(ServerUrls.s3ObjectDownloadUrl(rawUrl));
    AppLogger.i('JobTypeFieldsForm', 'Downloading ${f.name} from $uri');

    final request = http.Request('GET', uri)..headers.addAll(_authHeaders(apiClient));
    final streamedResponse = await request.send();
    AppLogger.i('JobTypeFieldsForm', 'Download response for ${f.name}: ${streamedResponse.statusCode}');
    if (streamedResponse.statusCode != 200) {
      throw Exception('HTTP ${streamedResponse.statusCode} downloading ${f.name}');
    }
    final bytes = await streamedResponse.stream.toBytes();

    var fileName = f.name;
    final contentDisposition = streamedResponse.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename[^;=\n]*=([^;\n]*)').firstMatch(contentDisposition);
    final extracted = match?.group(1);
    if (extracted != null && extracted.trim().isNotEmpty) {
      fileName = _cleanContentDispositionFileName(extracted);
    }

    return (bytes: bytes, fileName: fileName);
  }

  Future<void> _downloadFile(BuildContext context, AttachmentFile f) async {
    try {
      final attachment = await _fetchAttachment(context, f);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${attachment.fileName}');
      if (await file.exists()) await file.delete();
      await file.writeAsBytes(attachment.bytes);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${attachment.fileName} to ${file.path}'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e, st) {
      AppLogger.e('JobTypeFieldsForm', 'Could not download ${f.name}', e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download ${f.name}: ${friendlyError(e)}'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _dateField(BuildContext context, JobTypeField field, DateTime? current) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    final pickerBase = current ?? DateTime.now();
    final isDateTime = field.isDateTimePicker;
    final isTimeOnly = field.isTimePicker;
    return Padding(
      key: ValueKey(field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () async {
                if (isTimeOnly) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(pickerBase),
                    builder: (ctx, child) => Theme(data: pickerAppTheme(ctx), child: child!),
                  );
                  if (pickedTime == null) return;
                  final combined = DateTime(
                    pickerBase.year, pickerBase.month, pickerBase.day,
                    pickedTime.hour, pickedTime.minute,
                  );
                  onTextChanged(field.name, combined.toUtc().toIso8601String());
                  return;
                }
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: pickerBase,
                  firstDate: DateTime(pickerBase.year - 5),
                  lastDate: DateTime(pickerBase.year + 5),
                  builder: (ctx, child) => Theme(data: pickerAppTheme(ctx), child: child!),
                );
                if (pickedDate == null) return;
                if (!isDateTime) {
                  onTextChanged(field.name, pickedDate.toIso8601String());
                  return;
                }
                if (!context.mounted) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(pickerBase),
                  builder: (ctx, child) => Theme(data: pickerAppTheme(ctx), child: child!),
                );
                final combined = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime?.hour ?? pickerBase.hour,
                  pickedTime?.minute ?? pickerBase.minute,
                );
                onTextChanged(field.name, combined.toIso8601String());
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      current == null
                          ? 'Select ${field.label}'
                          : (isTimeOnly ? fmtTimeOnly(current) : (isDateTime ? fmtDateTimeDMY(current) : fmtDateDMY(current))),
                      style: AppFonts.body(size: 14.5, color: current == null ? AppColors.ink3 : AppColors.ink),
                    ),
                    Icon(isDateTime || isTimeOnly ? Icons.access_time : Icons.calendar_today_outlined, size: 16, color: AppColors.ink3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _selectionField(BuildContext context, JobTypeField field) {
    final options = optionsFor(field);
    final selected = field.multiselect
        ? (valueOf(field.name) as Set<String>?) ?? const <String>{}
        : {if (valueOf(field.name) != null) valueOf(field.name) as String};
    final selectedLabels = options.where((o) => selected.contains(o.submissionValue)).map((o) => o.label).join(', ');
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));

    return Padding(
      key: ValueKey(field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: options.isEmpty
                  ? null
                  : () => showSearchableOptionsPicker(
                        context,
                        title: field.label,
                        options: options,
                        multiselect: field.multiselect,
                        selectedValues: selected,
                        onSelect: (o) => field.multiselect ? onToggleMulti(field, o) : onPickSingle(field, o),
                      ),
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        options.isEmpty
                            ? 'No options available'
                            : selectedLabels.isEmpty
                                ? 'Select ${field.label}'
                                : selectedLabels,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.body(size: 14.5, color: selectedLabels.isEmpty ? AppColors.ink3 : AppColors.ink),
                      ),
                    ),
                    if (options.isNotEmpty) Icon(Icons.expand_more, size: 18, color: AppColors.ink3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dynamicTextField(JobTypeField field) {
    final keyboardType = field.isEmail
        ? TextInputType.emailAddress
        : field.isPhoneNumber
            ? TextInputType.phone
            : field.type == 'Numeric Text'
                ? TextInputType.number
                : TextInputType.text;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    return Padding(
      key: ValueKey(field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: TextFormField(
              initialValue: valueOf(field.name)?.toString() ?? '',
              keyboardType: keyboardType,
              maxLines: field.isTextArea || field.name.toLowerCase().contains('description') ? 3 : 1,
              onChanged: (v) => onTextChanged(field.name, v),
              style: AppFonts.body(size: 14.5, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: field.label,
                hintStyle: AppFonts.body(size: 14, color: AppColors.ink3),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool mandatory = false}) => Text(
        mandatory ? '$text *' : text,
        style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
      );
}

class _PercentTextField extends StatefulWidget {
  final JobTypeField field;
  final dynamic Function(String fieldName) valueOf;
  final void Function(String fieldName, String value) onTextChanged;

  const _PercentTextField({required this.field, required this.valueOf, required this.onTextChanged});

  @override
  State<_PercentTextField> createState() => _PercentTextFieldState();
}

class _PercentTextFieldState extends State<_PercentTextField> {
  late final _controller = TextEditingController(text: widget.valueOf(widget.field.name)?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    return Padding(
      key: ValueKey(widget.field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.field.mandatory ? '${widget.field.label} *' : widget.field.label,
            style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: AppFonts.body(size: 14.5, color: AppColors.ink),
              onChanged: (v) {
                final clean = v.replaceAll('%', '').trim();
                if (clean.isEmpty) {
                  widget.onTextChanged(widget.field.name, '');
                  return;
                }
                if (!_isValidPercent(widget.field.rule, clean)) {
                  final range = widget.field.rule.split(':').last;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Value must be within range $range'), behavior: SnackBarBehavior.floating),
                  );
                  _controller.clear();
                  widget.onTextChanged(widget.field.name, '');
                  return;
                }
                _controller.value = TextEditingValue(
                  text: '$clean%',
                  selection: TextSelection.collapsed(offset: clean.length),
                );
                widget.onTextChanged(widget.field.name, clean);
              },
              decoration: InputDecoration(
                hintText: widget.field.label,
                hintStyle: AppFonts.body(size: 14, color: AppColors.ink3),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaskedTextField extends StatefulWidget {
  final JobTypeField field;
  final dynamic Function(String fieldName) valueOf;
  final void Function(String fieldName, String value) onTextChanged;

  const _MaskedTextField({required this.field, required this.valueOf, required this.onTextChanged});

  @override
  State<_MaskedTextField> createState() => _MaskedTextFieldState();
}

class _MaskedTextFieldState extends State<_MaskedTextField> {
  late final _controller = TextEditingController(
    text: getMaskedValue(widget.valueOf(widget.field.name)?.toString() ?? '', widget.field.mask).formattedValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    return Padding(
      key: ValueKey(widget.field.name),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.field.mandatory ? '${widget.field.label} *' : widget.field.label,
            style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: TextFormField(
              controller: _controller,
              style: AppFonts.body(size: 14.5, color: AppColors.ink),
              inputFormatters: [MaskTextInputFormatter(widget.field.mask)],
              onChanged: (v) =>
                  widget.onTextChanged(widget.field.name, getMaskedValue(v, widget.field.mask).rawInput),
              decoration: InputDecoration(
                hintText: maskHint(widget.field.mask),
                hintStyle: AppFonts.body(size: 14, color: AppColors.ink3),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
