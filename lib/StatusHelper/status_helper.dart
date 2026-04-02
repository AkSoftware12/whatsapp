import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StatusHelper {
  // WhatsApp status paths (Android)
  static const List<String> _whatsappPaths = [
    '/storage/emulated/0/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
  ];

  // WhatsApp Business paths
  static const List<String> _whatsappBusinessPaths = [
    '/storage/emulated/0/WhatsApp Business/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
  ];

  static const List<String> _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  static const List<String> _videoExtensions = ['.mp4', '.mkv', '.3gp', '.avi', '.mov'];

  /// WhatsApp Images status list
  static Future<List<File>> getImageStatuses() async {
    return await _getStatuses(_imageExtensions);
  }

  /// WhatsApp Video status list
  static Future<List<File>> getVideoStatuses() async {
    return await _getStatuses(_videoExtensions);
  }

  static Future<List<File>> _getStatuses(List<String> extensions) async {
    List<File> statusFiles = [];

    List<String> allPaths = [..._whatsappPaths, ..._whatsappBusinessPaths];

    for (String path in allPaths) {
      Directory dir = Directory(path);
      if (await dir.exists()) {
        try {
          List<FileSystemEntity> entities = dir.listSync();
          for (FileSystemEntity entity in entities) {
            if (entity is File) {
              String ext = entity.path.split('.').last.toLowerCase();
              if (extensions.contains('.$ext')) {
                statusFiles.add(entity);
              }
            }
          }
        } catch (e) {
          print('Error reading directory $path: $e');
        }
      }
    }

    // Sort by modified time (newest first)
    statusFiles.sort((a, b) {
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });

    return statusFiles;
  }

  /// Saved statuses folder
  static Future<Directory> getSavedDirectory() async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String savedPath = '${appDir.path}/SavedStatuses';
    Directory savedDir = Directory(savedPath);
    if (!await savedDir.exists()) {
      await savedDir.create(recursive: true);
    }
    return savedDir;
  }

  /// Gallery mein saved statuses
  static Future<List<File>> getSavedStatuses() async {
    Directory savedDir = await getSavedDirectory();
    List<File> files = [];

    try {
      List<FileSystemEntity> entities = savedDir.listSync();
      for (FileSystemEntity entity in entities) {
        if (entity is File) {
          files.add(entity);
        }
      }
    } catch (e) {
      print('Error reading saved directory: $e');
    }

    files.sort((a, b) {
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });

    return files;
  }

  static bool isVideo(String path) {
    String ext = '.${path.split('.').last.toLowerCase()}';
    return _videoExtensions.contains(ext);
  }

  static bool isImage(String path) {
    String ext = '.${path.split('.').last.toLowerCase()}';
    return _imageExtensions.contains(ext);
  }

  /// File size format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}