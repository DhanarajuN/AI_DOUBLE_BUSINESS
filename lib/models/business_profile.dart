class BusinessProfile {
  final String name;
  final String owner;
  final String email;
  final String industryId;
  final String size;
  final String planId;
  final String region;
  final DateTime createdAt;

  const BusinessProfile({
    required this.name,
    required this.owner,
    required this.email,
    required this.industryId,
    required this.size,
    required this.planId,
    required this.region,
    required this.createdAt,
  });

  BusinessProfile copyWith({
    String? name,
    String? owner,
    String? industryId,
    String? size,
    String? planId,
  }) =>
      BusinessProfile(
        name: name ?? this.name,
        owner: owner ?? this.owner,
        email: email,
        industryId: industryId ?? this.industryId,
        size: size ?? this.size,
        planId: planId ?? this.planId,
        region: region,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'owner': owner,
        'email': email,
        'industryId': industryId,
        'size': size,
        'planId': planId,
        'region': region,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BusinessProfile.fromJson(Map<String, dynamic> json) => BusinessProfile(
        name: json['name'] as String,
        owner: json['owner'] as String? ?? '',
        email: json['email'] as String? ?? '',
        industryId: json['industryId'] as String,
        size: json['size'] as String? ?? '',
        planId: json['planId'] as String,
        region: json['region'] as String? ?? 'in',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
