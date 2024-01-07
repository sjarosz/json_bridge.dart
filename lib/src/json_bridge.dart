import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:path_provider/path_provider.dart';

/// Enum to specify the directory where the file will be created.
///
/// [applicationDocumentsDirectory] is the default directory.
enum PreferDir {
  applicationDocumentsDirectory,
  applicationSupportDirectory,
  externalStorageDirectory,
  libraryDirectory,
  temporaryDirectory,
  customDirectory // for when you want to use a custom directory
}

/// If it (data) can be a value in a `Map<String, dynamic>` you can save it into a json file with [JSONBridge].
///
/// [JSONBridge] is a simple wrapper around a JSON file
///
/// It allows you to store and retrieve data from a JSON file.
///
/// The JSON file is stored in the application document directory.
///
/// But you can also specify a directory and a file name when calling the init method.
///
/// This FORK of [JSONBridge] is NOT a singleton, rather leverages dependecy injection.
///
/// [JSONBridge] support manipulating nested keys with dot as separator.
///
/// Use [JSONBridge] to store user preferences, settings, data, etc.
///
/// Use [JSONBridge] to build the next big and powerful noSQL database for dart and flutter apps.
///
/// Use [JSONBridge] to store any data in a JSON file within your application.
///
/// Use [JSONBridge] to check if user is using your app for the first time.
///
/// Use [JSONBridge] to track user activity and show him the last seen screen when he restart the app.
///
/// Use cases are endless, use your imagination.
///

class DirectoryProvider {
  Future<Directory?> getDirectory(
      PreferDir preferDir, String? customDirPath) async {
    switch (preferDir) {
      case PreferDir.applicationDocumentsDirectory:
        return await getApplicationDocumentsDirectory();
      case PreferDir.applicationSupportDirectory:
        return await getApplicationSupportDirectory();
      case PreferDir.externalStorageDirectory:
        return await getExternalStorageDirectory();
      case PreferDir.libraryDirectory:
        return await getLibraryDirectory();
      case PreferDir.temporaryDirectory:
        return await getTemporaryDirectory();
      case PreferDir.customDirectory:
        return Directory(customDirPath!);
      default:
        return await getApplicationDocumentsDirectory();
    }
  }
}

class JSONBridge {
  File _file;
  bool _isInitialized = false;

  JSONBridge(this._file);

  static Future<JSONBridge> create(
      {String fileName = 'json_bridge_data.json',
      String? dir,
      PreferDir preferDir = PreferDir.applicationDocumentsDirectory,
      DirectoryProvider? directoryProvider}) async {
    directoryProvider ??= DirectoryProvider();

    Directory? directory;
    if (Platform.isAndroid || Platform.isIOS) {
      directory = await directoryProvider.getDirectory(preferDir, dir);
      if (directory == null) {
        throw Exception('JSONBridge: Directory cannot be null');
      }
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      directory = dir != null
          ? Directory(dir)
          : await directoryProvider.getDirectory(preferDir, null);

      // Handle desktop platforms here if necessary
    } else if (kIsWeb) {
      // Handle web (Chrome) specific logic here
      // Note: Filesystem operations are not supported in the same way on web
      // You might need to use browser-based storage solutions like LocalStorage or IndexedDB
    }

    if (!kIsWeb) {
      final filePath = '${directory!.path}/$fileName';
      final file = File(filePath);
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      return JSONBridge(file);
    } else {
      // Handle the web case differently
      // Example: You may want to create a web-specific file handler
      throw UnimplementedError(
          'JSONBridge is not implemented for web platforms.');
    }
  }

  void init() {
    _isInitialized = true;
  }

  /// Creates a JSON file in the application document directory or in the one provided.
  ///
  /// If the file already exists, file creation is skipped.
  ///
  /// You have to call this method before using the other methods.
  ///
  /// [fileName] is the name of the file to create. By default, the file name is `json_bridge_data`.
  ///
  /// [dir] is the directory where the file will be created. By default, the application document directory is used.
  ///
  ///If you specify a directory, you have to set permissions accordingly because you're accessing an external directory.
  ///
  ///Please refer to your target platform documentation for how to set permissions to access external directories.
  ///
  ///
  ///

  void _checkInitialization() {
    if (!_isInitialized) {
      throw Exception(
          'JSONBridge: Instance not initialized. Call init() before using.');
    }
  }

  /// Reads the JSON file and returns a Map.
  /// If the file is empty, an empty Map is returned.
  ///
  Map<String, dynamic> read() {
    _checkInitialization();

    if (_file.existsSync()) {
      String contents = _file.readAsStringSync();
      return contents.isNotEmpty ? json.decode(contents) : {};
    } else {
      return {};
    }
  }

  /// Writes a Map to the JSON file.
  ///
  /// This method overwrites the file content. It should therefore be used with caution.
  ///
  /// [data] is the Map to write.
  ///
  void write(Map<String, dynamic> data) {
    _file.writeAsStringSync(json.encode(data));
  }

  /// Deletes the JSON file.
  ///
  /// This method deletes the file. It should therefore be used with caution.
  void clear() {
    if (_file.existsSync()) {
      _file.deleteSync();
    }
  }

  /// Add or update a key with it value to the JSON file.
  ///
  /// [key] can be dot separated to access nested keys.
  ///
  /// If the [key] already exists, it will be overwritten like that we can use
  /// this method to update a key.
  ///
  /// [value] is the value to add or update.
  ///
  void set(String key, dynamic value) {
    Map<String, dynamic> data = read();

    // Ensure key is not empty
    if (key.isEmpty) {
      return;
    }

    // Check if key contains dot separated keys
    if (key.contains('.')) {
      // Ensure key don't start with a dot or end with a dot
      if (key.startsWith('.') || key.endsWith('.')) {
        return;
      }

      // Ensure key don't contains two dots in a consecutive way
      if (key.contains('..')) {
        return;
      }

      // Split the key into a list of keys
      List<String> keys = key.split('.');

      // Get the value of the before last key
      var beforeLastKey = get(keys.sublist(0, keys.length - 1).join('.'));

      // Ensure that the before last key is a Map
      if (beforeLastKey is Map) {
        // Add the last key with its value to the before last key
        beforeLastKey[keys.last] = value;
      } else {
        // If the before last key is not a Map, create a new Map
        beforeLastKey = {keys.last: value};
      }

      // Now loop through the keys and add them to the data starting from the last key -2 to the first key
      Map<String, dynamic> nestedData = beforeLastKey as Map<String, dynamic>;
      for (int i = keys.length - 2; i >= 0; i--) {
        nestedData = {keys[i]: nestedData};
      }

      // Add the nested data to the data
      data.addAll(nestedData);
    } else {
      data[key] = value;
    }
    write(data);
  }

  /// Delete a key from the JSON file.
  ///
  /// If the key doesn't exist, nothing happens.
  ///
  /// [key] can be dot separated to access nested keys.

  void delete(String key) {
    Map<String, dynamic> data = read();

    // Ensure key is not empty
    if (key.isEmpty) {
      return;
    }

    // Check if key contains dot separated keys
    if (key.contains('.')) {
      // Ensure key don't start with a dot or end with a dot
      if (key.startsWith('.') || key.endsWith('.')) {
        return;
      }

      // Ensure key don't contains two dots in a consecutive way
      if (key.contains('..')) {
        return;
      }

      // Split the key into a list of keys
      List<String> keys = key.split('.');

      // Get the value of the before last key
      var beforeLastKey = get(keys.sublist(0, keys.length - 1).join('.'));

      // Ensure that the before last key is a Map
      if (beforeLastKey is Map) {
        // Delete the last key
        beforeLastKey.remove(keys.last);
      }

      // Now loop through the keys and add them to the data starting from the last key -2 to the first key
      Map<String, dynamic> nestedData = beforeLastKey as Map<String, dynamic>;
      for (int i = keys.length - 2; i >= 0; i--) {
        nestedData = {keys[i]: nestedData};
      }

      // Add the nested data to the data
      data.addAll(nestedData);
    } else {
      data.remove(key);
    }
    write(data);
  }

  /// Get a value from the JSON file.
  dynamic get(String key) {
    // Ensure key is not empty
    if (key.isEmpty) {
      return false;
    }

    Map<String, dynamic> data = read();
    // When key contains a dot, it means that the key is nested.
    // We need to get the nested keys.
    if (key.contains('.')) {
      // Ensure key don't start with a dot or end with a dot
      if (key.startsWith('.') || key.endsWith('.')) {
        return;
      }

      // Ensure key don't contains two dots in a consecutive way
      if (key.contains('..')) {
        return;
      }

      List<String> keys = key.split('.');
      Map<String, dynamic> nestedData = data;
      for (int i = 0; i < keys.length - 1; i++) {
        // If the key is not found, return null
        if (!nestedData.containsKey(keys[i])) {
          return null;
        }
        nestedData = nestedData[keys[i]];
      }
      return nestedData[keys.last];
    } else {
      return data[key];
    }
  }

  /// Check if a key exists in the JSON file.
  ///
  /// [key] can be dot separated to access nested keys.
  ///
  /// Returns true if the key exists, false otherwise.
  bool has(String key) {
    return get(key) != null;
  }
}
