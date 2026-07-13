import 'package:path/path.dart' as p;
import 'package:psyconfig/psyconfig.dart';

/// Resolves the [ModelProfile] that matches an active model.
///
/// The active profile is determined from the model file name or tier URL. This
/// lets the prompt assembler and generation loop use model-specific stop
/// tokens, EOS tokens, and recommended context/KV-cache settings instead of
/// hard-coding one model's conventions.
class ModelProfileResolver {
  const ModelProfileResolver();

  /// Returns the best matching [ModelProfile] for [modelPath] from [config],
  /// or a fallback profile using [InferenceConfig.stopTokens] when no match
  /// is found.
  ModelProfile resolve(String modelPath, Config config) {
    final fileName = p.basename(modelPath).toLowerCase();
    for (final profile in config.modelProfiles.values) {
      if (fileName.contains(profile.modelKey.toLowerCase())) {
        return profile;
      }
    }
    return ModelProfile(
      modelKey: 'default',
      stopTokens: config.inference.stopTokens,
      recommendedNCtx: config.model.nCtx,
      recommendedKvCacheType: config.inference.kvCacheType,
    );
  }
}
