class GosureConversation {
  final String conversationId;
  final String? title;
  final String? user;
  final String? agentId;
  final String? businessId;
  // Server-resolved once at conversation creation (see librechat-backend's
  // resolveCustomerName / customerLookup.js) — the reliable source of the
  // customer's real name, unlike `user` (a raw internal id) or a message's
  // client-supplied senderName.
  final String? customerName;
  final bool agentChatMode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int messageCount;

  const GosureConversation({
    required this.conversationId,
    this.title,
    this.user,
    this.agentId,
    this.businessId,
    this.customerName,
    required this.agentChatMode,
    this.createdAt,
    this.updatedAt,
    this.messageCount = 0,
  });

  factory GosureConversation.fromJson(Map<String, dynamic> json) =>
      GosureConversation(
        conversationId: json['conversationId'] as String,
        title: json['title'] as String?,
        user: json['user'] as String?,
        agentId: json['agent_id'] as String?,
        businessId: json['businessId'] as String?,
        customerName: json['customerName'] as String?,
        // Defaults to true (agent replies) when absent, matching the backend's default state.
        agentChatMode: json['agentChatMode'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      );

  GosureConversation copyWith({bool? agentChatMode, DateTime? updatedAt}) =>
      GosureConversation(
        conversationId: conversationId,
        title: title,
        user: user,
        agentId: agentId,
        businessId: businessId,
        customerName: customerName,
        agentChatMode: agentChatMode ?? this.agentChatMode,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messageCount: messageCount,
      );
}
