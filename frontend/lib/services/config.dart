abstract final class AppConfig {
  /// Override with --dart-define=API_BASE_URL=...
  ///  * absolute: https://api.example.com/api/v1 (API on another host)
  ///  * relative: /api/v1 (API on the same origin as the site, e.g. Docker)
  ///  * empty:    no API at all; the site runs purely on the bundled seed
  static const _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080/api/v1');

  static bool get apiEnabled => _rawApiBaseUrl.trim().isNotEmpty;

  /// Absolute API base; relative values resolve against the page's origin.
  static final String apiBaseUrl = apiEnabled ? Uri.base.resolve(_rawApiBaseUrl.trim()).toString() : '';

  /// Resolves backend-relative paths such as /static/gallery/x.jpg.
  static Uri backendUri(String path) => Uri.parse(apiBaseUrl).resolve(path);

  static const cvFileName = 'Prof_Dr_Srijan_Lal_Shrestha_CV.pdf';
  static const cvAsset = 'assets/docs/$cvFileName';
}
