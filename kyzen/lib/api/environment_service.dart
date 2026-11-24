import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class EnvironmentConfig {
  final String name;
  final String titleId;
  final String sharedSecret;
  final bool isDefault;

  const EnvironmentConfig({
    required this.name,
    required this.titleId,
    required this.sharedSecret,
    this.isDefault = false,
  });

  factory EnvironmentConfig.fromJson(Map<String, dynamic> json) =>
      EnvironmentConfig(
        name: json['name'] as String,
        titleId: json['titleId'] as String,
        sharedSecret: json['sharedSecret'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'titleId': titleId,
    'sharedSecret': sharedSecret,
    'isDefault': isDefault,
  };
}

class EnvironmentService {
  static final EnvironmentService instance = EnvironmentService._internal();
  EnvironmentService._internal();
  factory EnvironmentService() => instance;
  EnvironmentConfig? _activeEnv;

  static bool get shouldUploadKeys => instance._activeEnv?.isDefault ?? true;

  static const String _fileName = 'environments.json';
  static const String _activeKey = 'activeEnvironment';

  static const EnvironmentConfig defaultEnv = EnvironmentConfig(
    name: 'Production',
    titleId: '20CA2',
    sharedSecret: 'S8RS53ZEIGMYTYG856U3U19AORWXQXF41J7FT3X9YCWAC7I35X',
    isDefault: true,
  );

  List<EnvironmentConfig>? _environments;
  String? _activeEnvName;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    final file = await _getFile();
    await file.writeAsString(json.encode(data));
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return {};
      return json.decode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('EnvironmentService load error: $e');
      return {};
    }
  }

  Future<List<EnvironmentConfig>> getEnvironments() async {
    if (_environments != null) return _environments!;
    final data = await _load();
    final list =
        (data['environments'] as List<dynamic>?)
            ?.map((e) => EnvironmentConfig.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    _environments = list;
    return _environments!;
  }

  Future<EnvironmentConfig> getActiveEnvironment() async {
    final data = await _load();
    _activeEnvName = data[_activeKey] as String?;
    if (_activeEnvName == null) return defaultEnv;
    final envs = await getEnvironments();
    return envs.firstWhere(
      (e) => e.name == _activeEnvName,
      orElse: () => defaultEnv,
    );
  }

  Future<void> addEnvironment(EnvironmentConfig env) async {
    final envs = await getEnvironments();
    envs.add(env);
    _environments = envs;
    final data = await _load();
    data['environments'] = envs.map((e) => e.toJson()).toList();
    await _persist(data);
  }

  Future<void> setActiveEnvironment(String name) async {
    _activeEnvName = name;
    final data = await _load();
    data[_activeKey] = name;
    await _persist(data);
  }

  Future<void> deleteEnvironment(String name) async {
    final envs = await getEnvironments();
    _environments = envs.where((e) => e.name != name).toList();
    final data = await _load();
    data['environments'] = _environments!.map((e) => e.toJson()).toList();
    if (data[_activeKey] == name) data.remove(_activeKey);
    await _persist(data);
  }

  void cacheActiveEnvironment(EnvironmentConfig env) {
    _activeEnv = env;
  }
}
