class JobStatusOption {
  final String secondaryStatus;
  final List<String> roleNames;
  final String? subJobTypeName;
  final String? subJobTypeId;

  const JobStatusOption({
    required this.secondaryStatus,
    required this.roleNames,
    this.subJobTypeName,
    this.subJobTypeId,
  });

  factory JobStatusOption.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List?) ?? const [];
    final subJobTypes = (json['subJobType'] as List?) ?? const [];
    final firstSubJob = subJobTypes.isNotEmpty && subJobTypes.first is Map
        ? Map<String, dynamic>.from(subJobTypes.first as Map)
        : null;
    return JobStatusOption(
      secondaryStatus: (json['secondaryStatus'] as String? ?? '').trim(),
      roleNames: roles
          .whereType<Map>()
          .map((r) => (r['name'] as String? ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toList(),
      subJobTypeName: firstSubJob?['name'] as String?,
      subJobTypeId: (firstSubJob?['id'] ?? firstSubJob?['_id'])?.toString(),
    );
  }

  bool get requiresSubJobForm => subJobTypeName != null && subJobTypeName!.isNotEmpty;

  bool allowsRole(String? roleName) =>
      roleNames.isEmpty ||
      (roleName != null && roleNames.any((r) => r.toLowerCase() == roleName.toLowerCase()));
}
