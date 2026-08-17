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
