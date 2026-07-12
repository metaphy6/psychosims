import 'config.dart';
import 'loader.dart';

/// Provider that loads and holds the immutable validated configuration once.
class ConfigProvider {
  final Config config;

  ConfigProvider._(this.config);

  factory ConfigProvider.forEnvironment({
    required String environment,
    Map<String, String> platformEnvironment = const {},
  }) {
    return ConfigProvider._(
      loadConfig(
        environment: environment,
        platformEnvironment: platformEnvironment,
      ),
    );
  }
}
