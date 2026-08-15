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

  static const String librechatURL = String.fromEnvironment(
    'LIBRECHAT_URL',
    defaultValue: 'https://librechat-backend-olj53mb3da-el.a.run.app',
  );

  static const String coreMcpUrl = String.fromEnvironment(
    'CORE_MCP_URL',
    defaultValue: 'https://dev.gosure.ai',
  );

  static const String gosureConvos = '/api/gosure/convos';
}
