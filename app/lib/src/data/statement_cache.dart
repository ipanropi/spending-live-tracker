import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';

/// Keeps the last statement on the device, so the app opens instantly with it
/// while fresh data loads. Stored in the app's private support folder.
class StatementCache {
  const StatementCache();

  static const String _fileName = 'statement.json';

  Future<File?> _file() async {
    if (kIsWeb) return null; // the web build is only used for screenshots
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<Statement?> read() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['version'] != Statement.cacheVersion) return null;
      return Statement.fromJson(json);
    } on Object {
      return null; // a corrupt or old cache is simply ignored
    }
  }

  Future<void> write(Statement statement) async {
    try {
      final file = await _file();
      if (file == null) return;
      await file.parent.create(recursive: true);
      // Write then rename, so a crash mid-write never leaves a half-written cache.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(statement.toJson()), flush: true);
      await tmp.rename(file.path);
    } on Object {
      // Caching is a nice-to-have; never fail an update over it.
    }
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (file != null && await file.exists()) await file.delete();
    } on Object {
      // nothing to clear
    }
  }
}
