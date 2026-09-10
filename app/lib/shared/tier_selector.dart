import 'dart:io';
import 'dart:convert';

import 'package:psyconfig/psyconfig.dart';

/// Snapshot of the device's hardware capabilities used to choose a model tier.
class DeviceCapability {
  /// Total physical RAM, in bytes.
  final int totalRamBytes;

  /// Best-effort available RAM, in bytes.
  final int availableRamBytes;

  /// ABI reported by the runtime, e.g. `arm64-v8a`, `x86_64`, `armeabi-v7a`.
  final String abi;

  /// Whether the CPU supports AVX2 (relevant for x86-64 desktop targets).
  final bool hasAvx2;

  /// Number of CPU cores visible to the runtime.
  final int cpuCount;

  /// Whether the runtime is running inside an emulator.
  final bool isEmulator;

  const DeviceCapability({
    required this.totalRamBytes,
    required this.availableRamBytes,
    required this.abi,
    required this.hasAvx2,
    required this.cpuCount,
    required this.isEmulator,
  });
}

/// Selected model tier.
enum TierSelection {
  /// Primary Tier A model (largest, highest quality).
  tierAPrimary,

  /// Fallback within Tier A (comparator/smaller backup model).
  tierAFallback,

  /// Tier B fallback (smallest footprint).
  tierB,
}

/// Resolved source metadata for a selected tier.
class ModelSource {
  /// Remote URL where the model weights are fetched.
  final String url;

  /// Expected SHA-256 checksum, or `null` if not pinned yet.
  final String? checksum;

  /// Suggested local file name derived from the URL.
  final String fileName;

  /// Tier this source belongs to.
  final TierSelection tier;

  /// Quantization profile from config.
  final String quantization;

  const ModelSource({
    required this.url,
    this.checksum,
    required this.fileName,
    required this.tier,
    required this.quantization,
  });
}

/// Selects the appropriate model tier for a device and resolves the source URL.
///
/// The policy is an implementation of the [DEVICE-SPEC] floor: devices that do
/// not meet the Tier A floor are routed to Tier B; devices that meet the floor
/// but have constrained headroom (or are emulators) use the Tier A fallback.
class TierSelector {
  /// Returns the best tier for [device] according to [config].
  TierSelection select(DeviceCapability device, Config config) {
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final is64Bit = device.abi.contains('64');
    // AVX2 is only relevant on x86-64 desktop targets.
    final isX86_64Desktop = isDesktop && device.abi == 'x86_64';

    // Hard floor: insufficient total RAM, 32-bit ABI, or x86-64 desktop without
    // AVX2 cannot safely run the Tier A primary model.
    if (device.totalRamBytes < config.model.tierAFloorBytes ||
        !is64Bit ||
        (isX86_64Desktop && !device.hasAvx2)) {
      return TierSelection.tierB;
    }

    // Soft floor: low available-RAM headroom or an emulator moves to the
    // smaller Tier A fallback. Emulators are treated conservatively because
    // they are used for development/CI validation and may not reflect the
    // performance characteristics of the physical floor devices measured in
    // Phase 1.6.
    if (device.availableRamBytes < config.model.tierAAvailableHeadroomBytes ||
        device.isEmulator) {
      return TierSelection.tierAFallback;
    }

    return TierSelection.tierAPrimary;
  }

  /// Resolves the configured source for [tier].
  ModelSource resolveSource(TierSelection tier, Config config) {
    final String url;
    switch (tier) {
      case TierSelection.tierAPrimary:
        url = config.model.tierAPrimaryUrl;
      case TierSelection.tierAFallback:
        url = config.model.tierAFallbackUrl;
      case TierSelection.tierB:
        url = config.model.tierBUrl;
    }

    final fileName = _fileNameFromUrl(url);
    final checksum = config.model.modelChecksums[url];

    return ModelSource(
      url: url,
      checksum: checksum,
      fileName: fileName,
      tier: tier,
      quantization: config.model.quantization,
    );
  }

  String _fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments.last.isNotEmpty) {
        return segments.last;
      }
    } on FormatException {
      // Fall through to basename extraction.
    }
    final lastSlash = url.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < url.length - 1) {
      return url.substring(lastSlash + 1);
    }
    return 'model.gguf';
  }
}

/// Abstract seam for reading device capabilities so tests can inject values.
abstract class DeviceCapabilityProvider {
  DeviceCapability getCapabilities();
}

/// Best-effort [DeviceCapabilityProvider] using `dart:io` platform signals.
///
/// RAM is read from `/proc/meminfo` when available. ABI is inferred from
/// [Platform.version]. Linux AVX2 support requires flags on every advertised CPU;
/// unavailable platform probes conservatively select a smaller tier.
class DefaultDeviceCapabilityProvider implements DeviceCapabilityProvider {
  static const int _fallbackRamBytes = 4294967296; // 4 GiB

  @override
  DeviceCapability getCapabilities() {
    final memInfo = _readMemInfo();
    final abi = _detectAbi();
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    return DeviceCapability(
      totalRamBytes: memInfo.total,
      availableRamBytes: memInfo.available,
      abi: abi,
      hasAvx2: isDesktop && Platform.isLinux && _readAvx2(),
      cpuCount: Platform.numberOfProcessors,
      isEmulator: false,
    );
  }

  static bool hasAvx2InCpuInfo(String text) {
    final flags = const LineSplitter()
        .convert(text)
        .where((line) => RegExp(r'^flags\s*:').hasMatch(line.trimLeft()))
        .map((line) => line.split(':').last.trim().split(RegExp(r'\s+')))
        .toList();
    return flags.isNotEmpty && flags.every((values) => values.contains('avx2'));
  }

  bool _readAvx2() {
    try {
      return hasAvx2InCpuInfo(File('/proc/cpuinfo').readAsStringSync());
    } on FileSystemException {
      return false;
    }
  }

  ({int total, int available}) _readMemInfo() {
    try {
      final file = File('/proc/meminfo');
      if (!file.existsSync()) {
        return _fallbackMemInfo();
      }
      final lines = file.readAsLinesSync();
      var total = 0;
      var available = 0;
      for (final line in lines) {
        final totalMatch = RegExp(r'^MemTotal:\s+(\d+)\s+kB').firstMatch(line);
        final availableMatch =
            RegExp(r'^MemAvailable:\s+(\d+)\s+kB').firstMatch(line);
        if (totalMatch != null) {
          total = int.parse(totalMatch.group(1)!) * 1024;
        }
        if (availableMatch != null) {
          available = int.parse(availableMatch.group(1)!) * 1024;
        }
      }
      if (total <= 0) return _fallbackMemInfo();
      if (available <= 0) available = total;
      return (total: total, available: available);
    } on Exception {
      return _fallbackMemInfo();
    }
  }

  ({int total, int available}) _fallbackMemInfo() {
    return (
      total: _fallbackRamBytes,
      available: _fallbackRamBytes,
    );
  }

  String _detectAbi() {
    final version = Platform.version;
    final lower = version.toLowerCase();

    // Flutter/Dart VM version strings include the target ABI near the end,
    // e.g. "... on "android_arm64"" or "... on "linux_x64"".
    if (lower.contains('android_arm64')) {
      return 'arm64-v8a';
    }
    if (lower.contains('android_x64')) {
      return 'x86_64';
    }
    if (lower.contains('android_arm')) {
      return 'armeabi-v7a';
    }
    if (lower.contains('android_ia32') || lower.contains('android_i386')) {
      return 'x86';
    }
    if (lower.contains('linux_x64') || lower.contains('linux_amd64')) {
      return 'x86_64';
    }
    if (lower.contains('linux_arm64') || lower.contains('linux_aarch64')) {
      return 'arm64';
    }
    if (lower.contains('macos_x64') || lower.contains('macos_amd64')) {
      return 'x86_64';
    }
    if (lower.contains('macos_arm64') || lower.contains('macos_apple')) {
      return 'arm64';
    }
    if (lower.contains('windows_x64')) {
      return 'x86_64';
    }

    return 'unknown';
  }
}
