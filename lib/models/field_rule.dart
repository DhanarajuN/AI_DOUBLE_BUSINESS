class FieldRule {
  final Map<String, String> groupByValue;
  final List<String> controlledGroups;

  const FieldRule({required this.groupByValue, required this.controlledGroups});

  factory FieldRule.fromJson(Map<String, dynamic> json) {
    final ruleDetails = (json['ruleDetails'] as Map?) ?? const {};
    final ruleGroupNames = (json['ruleGroupNames'] as List?) ?? const [];
    return FieldRule(
      groupByValue: ruleDetails.map((k, v) => MapEntry(k.toString(), v.toString())),
      controlledGroups: ruleGroupNames.map((e) => e.toString()).toList(),
    );
  }

  String? groupToShowFor(String? selectedValue) => selectedValue == null ? null : groupByValue[selectedValue];
}
