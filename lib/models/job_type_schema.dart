class JobTypeFieldOption {
  final String id;
  final String label;

  const JobTypeFieldOption({required this.id, required this.label});

  factory JobTypeFieldOption.fromJson(Map<String, dynamic> json) => JobTypeFieldOption(
        id: json['jobInstanceId']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );
}

class JobTypeFieldQueryResult {
  final List<JobTypeFieldOption> singleLevel;
  final Map<String, List<JobTypeFieldOption>> twoLevelByParentLabel;

  const JobTypeFieldQueryResult({required this.singleLevel, required this.twoLevelByParentLabel});

  static const empty = JobTypeFieldQueryResult(singleLevel: [], twoLevelByParentLabel: {});

  factory JobTypeFieldQueryResult.fromJson(Map<String, dynamic> json) {
    final single = ((json['singleLevelResults'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => JobTypeFieldOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final twoLevel = <String, List<JobTypeFieldOption>>{};
    for (final entry in (json['twoLevelResults'] as List?) ?? const []) {
      if (entry is! Map) continue;
      final rawId = entry['_id']?.toString() ?? '';
      final parenIndex = rawId.indexOf('(');
      final parentLabel = parenIndex > 0 ? rawId.substring(0, parenIndex) : rawId;
      final next = ((entry['nextLevel'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => JobTypeFieldOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      twoLevel[parentLabel] = next;
    }

    return JobTypeFieldQueryResult(singleLevel: single, twoLevelByParentLabel: twoLevel);
  }
}

class JobTypeField {
  final String langLabel;
  final int order;
  final String name;
  final String displayName;
  final String type;
  final bool mandatory;
  final bool multiselect;
  final String groupName;
  final String dependentFields;
  final String allowedValuesRaw;
  final String uniqueFieldId;
  final String rule;

  const JobTypeField({
    required this.langLabel,
    required this.order,
    required this.name,
    required this.displayName,
    required this.type,
    required this.mandatory,
    required this.multiselect,
    required this.groupName,
    required this.dependentFields,
    required this.allowedValuesRaw,
    required this.uniqueFieldId,
    required this.rule,
  });

  factory JobTypeField.fromJson(Map<String, dynamic> json) => JobTypeField(
        langLabel: json['lang_label']?.toString() ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        mandatory: json['mandatory'] == true,
        multiselect: json['multiselect'] == true,
        groupName: json['groupName']?.toString() ?? '',
        dependentFields: json['dependentFields']?.toString() ?? '',
        allowedValuesRaw: json['allowedValues']?.toString() ?? '',
        uniqueFieldId: json['uniqueFieldId']?.toString() ?? '',
        rule: json['rule']?.toString() ?? '',
      );

  String get label => displayName.isNotEmpty ? displayName : name;

  bool get isSubJob => type == 'SubJob';

  bool get isQueryDriven => allowedValuesRaw.startsWith('q:');

  String? get queryKey => isQueryDriven ? allowedValuesRaw : null;

  List<String> get staticOptions => isQueryDriven || allowedValuesRaw.isEmpty
      ? const []
      : allowedValuesRaw.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

class JobTypeSchema {
  final String jobTypeId;
  final String jobTypeName;
  final List<JobTypeField> fields;
  final Map<String, JobTypeFieldQueryResult> queries;

  const JobTypeSchema({
    required this.jobTypeId,
    required this.jobTypeName,
    required this.fields,
    required this.queries,
  });

  factory JobTypeSchema.fromJson(Map<String, dynamic> json) {
    final jobType = json['jobType'] is Map ? Map<String, dynamic>.from(json['jobType'] as Map) : <String, dynamic>{};
    final properties = jobType['properties'] is Map ? Map<String, dynamic>.from(jobType['properties'] as Map) : <String, dynamic>{};
    final orgs = (properties['orgs'] as List?) ?? const [];
    final org = orgs.isNotEmpty && orgs.first is Map ? Map<String, dynamic>.from(orgs.first as Map) : <String, dynamic>{};
    final fieldsRaw = (org['Fields'] as List?) ?? const [];
    final fields = fieldsRaw.whereType<Map>().map((f) => JobTypeField.fromJson(Map<String, dynamic>.from(f))).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final queriesRaw = json['queries'] is Map ? Map<String, dynamic>.from(json['queries'] as Map) : <String, dynamic>{};
    final queries = <String, JobTypeFieldQueryResult>{
      for (final entry in queriesRaw.entries)
        entry.key: JobTypeFieldQueryResult.fromJson(entry.value is Map ? Map<String, dynamic>.from(entry.value as Map) : {}),
    };

    return JobTypeSchema(
      jobTypeId: jobType['id']?.toString() ?? '',
      jobTypeName: jobType['name']?.toString() ?? '',
      fields: fields,
      queries: queries,
    );
  }

  List<JobTypeField> fieldsInGroup(String groupName) => fields.where((f) => f.groupName == groupName).toList();

  JobTypeField? fieldNamed(String name) {
    for (final f in fields) {
      if (f.name == name) return f;
    }
    return null;
  }

  JobTypeField? fieldByLangLabel(String langLabel) {
    for (final f in fields) {
      if (f.langLabel == langLabel) return f;
    }
    return null;
  }

  List<String> optionsFor(JobTypeField field, {String? parentSelectionLabel}) {
    if (!field.isQueryDriven) return field.staticOptions;
    final result = queries[field.queryKey];
    if (result == null) return const [];
    if (result.singleLevel.isNotEmpty) return result.singleLevel.map((o) => o.label).toList();
    if (parentSelectionLabel == null) return const [];
    return (result.twoLevelByParentLabel[parentSelectionLabel] ?? const []).map((o) => o.label).toList();
  }
}
