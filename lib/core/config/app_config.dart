class AppConfig {
  const AppConfig._();

  static const recognitionBaseUrl = String.fromEnvironment(
    'RECOGNITION_BASE_URL',
    defaultValue: 'https://recognition-camera-production.up.railway.app',
  );

  static const recognitionAnalyzePath = '/analyze/';

  static const openFoodFactsBaseUrl = 'https://world.openfoodfacts.org';
}
