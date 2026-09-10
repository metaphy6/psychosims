import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Production failures propagate. There is deliberately no file/memory fallback.
abstract interface class SecretStorage {
  String get scope;
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecretStorage implements SecretStorage {
  PlatformSecretStorage({required this.scope, FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
                aOptions: AndroidOptions(resetOnError: false));
  @override
  final String scope;
  final FlutterSecureStorage _storage;
  String _key(String key) => '$scope.$key';
  @override
  Future<String?> read(String key) => _storage.read(key: _key(key));
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: _key(key), value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: _key(key));
}

/// Coordinates multiple service instances using the same backing store.
class SerialOperations {
  static final Map<String, Future<void>> _tails = {};
  static Future<T> run<T>(String scope, Future<T> Function() operation) {
    final previous = _tails[scope] ?? Future<void>.value();
    final completed = Completer<void>();
    final next = completed.future;
    _tails[scope] = next;
    return previous.then((_) => operation()).whenComplete(() {
      completed.complete();
      if (identical(_tails[scope], next)) _tails.remove(scope);
    });
  }
}

/// Namespaces a secure store without changing its custody guarantees.
class ScopedSecretStorage implements SecretStorage {
  ScopedSecretStorage(this.parent, this.namespace);
  final SecretStorage parent;
  final String namespace;
  @override
  String get scope => '${parent.scope}.$namespace';
  String _key(String key) => '$namespace.$key';
  @override
  Future<String?> read(String key) => parent.read(_key(key));
  @override
  Future<void> write(String key, String value) =>
      parent.write(_key(key), value);
  @override
  Future<void> delete(String key) => parent.delete(_key(key));
}
