class ServerUrls {
  ServerUrls._();

  static const String baseUrl = 'https://$tenant.dev.gosure.ai';

  static const String tenant = 'aidouble';

  static const String login = '/api/v1/users/login';

  static const String moduleConstants = '/api/v1/module-constants';

  static const String ssoCallbackScheme = 'aidoublebusiness';

  static const String ssoCallbackUrl = '$ssoCallbackScheme://auth-redirect';

  static const String ssoGoogleLogin = '/api/v1/sso/Google/login';

  static const String ssoSessionLogin = '/api/v1/users/sso/session-login';

  static const String rolesByName = '/api/v1/roles/name';

  static const String users = '/api/v1/users';

  static const String usersUpdate = '/api/v1/users/update';

  static const String businessInstances =
      '/api/v1/job-types/name/Business/instances';

  static String jobTypeInstances(String typeName) =>
      '/api/v1/job-types/name/$typeName/instances';

  static String jobTypeCreateInstance(String typeName) =>
      '/api/v1/job-types/create/instance/$typeName';

  static const String jobInstances = '/api/v1/job-instances';

  static const String attachmentsOnlyUpload = '/api/v1/job-instances/attachments-only';

  static const String updateWorkflowStatus =
      '/api/v1/job-instances/update-workflow-status';

  static const String publicInstanceCreate = '/api/v1/public/create-instance';

  static const String s3ObjectDownload = '/api/v1/s3-objects/download';

  static String s3ObjectDownloadUrl(String url) =>
      '$baseUrl$s3ObjectDownload?url=${Uri.encodeQueryComponent(url)}';

  static const String coreMcpConfigurations = '/core-mcp/configurations';

  static const String librechatURL = String.fromEnvironment(
    'LIBRECHAT_URL',
    defaultValue: 'https://librechat-backend-olj53mb3da-el.a.run.app',
  );

  static const String coreMcpUrl = String.fromEnvironment(
    'CORE_MCP_URL',
    defaultValue: 'https://dev.gosure.ai',
  );

  static const String gosureConvos = '/api/gosure/convos';

  static const String gosureConvoMessages = 'messages';

  static const String gosureConvoEvents = 'events';

  static const String gosureConvoAgentMode = 'agent-mode';

  static const String openAiChatCompletions =
      'https://api.openai.com/v1/chat/completions';

  static const String anthropicMessages = 'https://api.anthropic.com/v1/messages';

  static const String geminiModels =
      'https://generativelanguage.googleapis.com/v1beta/models';
}
