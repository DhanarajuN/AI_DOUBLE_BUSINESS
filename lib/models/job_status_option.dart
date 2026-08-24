class JobStatusOption {
  final String secondaryStatus;
  final List<String> roleNames;

  const JobStatusOption({required this.secondaryStatus, required this.roleNames});

  factory JobStatusOption.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List?) ?? const [];
    return JobStatusOption(
      secondaryStatus: (json['secondaryStatus'] as String? ?? '').trim(),
      roleNames: roles
          .whereType<Map>()
          .map((r) => (r['name'] as String? ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toList(),
    );
  }

  bool allowsRole(String? roleName) =>
      roleNames.isEmpty ||
      (roleName != null && roleNames.any((r) => r.toLowerCase() == roleName.toLowerCase()));
}
