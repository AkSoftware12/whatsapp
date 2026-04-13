import 'dart:async';
import 'dart:io';

import 'package:docman/docman.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const _prefsTreeUriKey = 'whatsapp_tree_uri';
const _galleryAlbumName = 'Status Saver';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StatusSaverApp());
}

class StatusSaverApp extends StatelessWidget {
  const StatusSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp Status Saver',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF6F3EA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
      ),
      home: const StatusSaverHomePage(),
    );
  }
}

class StatusItem {
  const StatusItem({
    required this.name,
    required this.modifiedAt,
    required this.isVideo,
    this.localFile,
    this.document,
  });

  final String name;
  final DateTime? modifiedAt;
  final bool isVideo;
  final File? localFile;
  final DocumentFile? document;

  bool get isImage => !isVideo;
  String get typeLabel => isVideo ? 'Video' : 'Image';
  String get id => document?.uri ?? localFile!.path;

  Future<File?> previewFile() async {
    if (localFile != null) return localFile;
    if (document == null) return null;
    if (isVideo) {
      return document!.thumbnailFile(width: 512, height: 512, quality: 80);
    }
    return document!.cache(imageQuality: 80);
  }

  Future<File?> cacheFile() async {
    if (localFile != null) return localFile;
    return document?.cache();
  }

  Future<void> share() async {
    if (document != null) {
      await document!.share(title: 'Share status');
      return;
    }
    if (localFile == null) return;
    final tempDoc = DocumentFile(
      uri: localFile!.path,
      name: name,
      exists: true,
      type: isVideo ? 'video/mp4' : 'image/jpeg',
    );
    await tempDoc.share(title: 'Share status');
  }
}

enum AccessMode { directPermission, saf }

class StatusSaverHomePage extends StatefulWidget {
  const StatusSaverHomePage({super.key});

  @override
  State<StatusSaverHomePage> createState() => _StatusSaverHomePageState();
}

class _StatusSaverHomePageState extends State<StatusSaverHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, Future<File?>> _previewFutures = {};

  bool _loading = true;
  bool _refreshing = false;
  bool _selectingFolder = false;
  String? _error;
  String? _folderHint;
  AccessMode? _accessMode;
  List<StatusItem> _allStatuses = const [];
  DocumentFile? _selectedDirectory;
  DocumentFile? _statusesDirectory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final directStatuses = await _tryDirectPermissionFlow(showErrors: false);
      if (directStatuses != null) {
        _setDirectState(directStatuses);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedUri = prefs.getString(_prefsTreeUriKey);
      if (savedUri != null && savedUri.isNotEmpty) {
        final restored = await DocumentFile(uri: savedUri).get();
        if (restored != null && restored.exists && restored.isDirectory) {
          await _loadSafStatuses(restored, saveSelection: false);
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _folderHint = 'Pehle direct permission try hui. Android 11+ par hidden status folder ke liye aksar SAF picker ki zarurat padti hai.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<List<StatusItem>?> _tryDirectPermissionFlow({required bool showErrors}) async {
    final granted = await _requestDirectPermissions();
    if (!granted) {
      if (showErrors && mounted) {
        setState(() {
          _error = 'Direct permission allow nahi hui. SAF picker use karo.';
          _folderHint = 'Android 11+ par simple allow se hidden `.Statuses` folder direct open nahi hota.';
        });
      }
      return null;
    }

    final statuses = await _loadDirectStatuses();
    if (statuses.isEmpty) {
      if (showErrors && mounted) {
        setState(() {
          _error = 'Direct permission mil gayi, lekin hidden status folder direct access se read nahi hua.';
          _folderHint = 'Is device par SAF folder selection reliable rahega.';
        });
      }
      return null;
    }
    return statuses;
  }

  Future<bool> _requestDirectPermissions() async {
    if (!Platform.isAndroid) return false;

    final imageStatus = await Permission.photos.request();
    final videoStatus = await Permission.videos.request();

    if (imageStatus.isGranted && videoStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted ||
        ((await Permission.photos.status).isGranted &&
            (await Permission.videos.status).isGranted);
  }

  Future<List<StatusItem>> _loadDirectStatuses() async {
    final candidateDirs = <String>[
      '/storage/emulated/0/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/WhatsApp Business/Media/.Statuses',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    ];

    final files = <FileSystemEntity>[];
    for (final dirPath in candidateDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      try {
        files.addAll(await dir.list().toList());
      } catch (_) {}
    }

    final statuses = files
        .whereType<File>()
        .where((file) {
          final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
          return name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png') ||
              name.endsWith('.webp') ||
              name.endsWith('.mp4');
        })
        .map((file) {
          final stat = file.statSync();
          final name = file.path.split(Platform.pathSeparator).last;
          return StatusItem(
            name: name,
            modifiedAt: stat.modified,
            isVideo: name.toLowerCase().endsWith('.mp4'),
            localFile: file,
          );
        })
        .toList()
      ..sort((a, b) => (b.modifiedAt ?? DateTime(1970)).compareTo(a.modifiedAt ?? DateTime(1970)));

    return statuses;
  }

  void _setDirectState(List<StatusItem> statuses) {
    if (!mounted) return;
    _previewFutures.clear();
    setState(() {
      _loading = false;
      _accessMode = AccessMode.directPermission;
      _allStatuses = statuses;
      _error = statuses.isEmpty ? 'Direct access me koi status nahi mila.' : null;
      _folderHint = 'Direct permission mode active hai. Agar kuch statuses miss hon, SAF picker use karo.';
      _selectedDirectory = null;
      _statusesDirectory = null;
    });
  }
  Future<void> _pickFolder() async {
    if (_selectingFolder) return;

    setState(() {
      _selectingFolder = true;
      _error = null;
    });

    try {
      final picked = await DocMan.pick.directory(initDir: _selectedDirectory?.uri);
      if (picked == null) {
        if (!mounted) return;
        setState(() => _selectingFolder = false);
        return;
      }
      await _loadSafStatuses(picked, saveSelection: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectingFolder = false;
        _loading = false;
        _error = 'Folder select karte waqt issue aaya: $e';
      });
    }
  }

  Future<void> _loadSafStatuses(DocumentFile selected, {required bool saveSelection}) async {
    setState(() {
      _loading = true;
      _selectingFolder = false;
      _error = null;
    });

    try {
      final statusesDir = await _resolveStatusesDirectory(selected);
      if (statusesDir == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _selectedDirectory = selected;
          _statusesDirectory = null;
          _allStatuses = const [];
          _accessMode = AccessMode.saf;
          _error = '`.Statuses` folder nahi mila. `WhatsApp/Media` ya `Android/media/.../Media` folder select karo.';
        });
        return;
      }

      final files = await statusesDir.listDocuments(
        extensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4'],
      );

      final statuses = files
          .where((file) => file.isFile)
          .where((file) => !file.name.startsWith('.'))
          .map((file) => StatusItem(
                name: file.name,
                modifiedAt: file.lastModifiedDate,
                isVideo: file.name.toLowerCase().endsWith('.mp4'),
                document: file,
              ))
          .toList()
        ..sort((a, b) => (b.modifiedAt ?? DateTime(1970)).compareTo(a.modifiedAt ?? DateTime(1970)));

      if (saveSelection) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsTreeUriKey, selected.uri);
      }

      _previewFutures.clear();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _accessMode = AccessMode.saf;
        _selectedDirectory = selected;
        _statusesDirectory = statusesDir;
        _allStatuses = statuses;
        _folderHint = 'SAF mode active hai. Ye Android 11+ par sabse reliable method hai.';
        _error = statuses.isEmpty ? 'Status folder mil gaya, lekin visible status nahi mila.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Statuses load nahi huye: $e';
      });
    }
  }

  Future<DocumentFile?> _resolveStatusesDirectory(DocumentFile selected) async {
    if (!selected.exists || !selected.isDirectory) return null;
    if (selected.name == '.Statuses') return selected;

    Future<DocumentFile?> child(DocumentFile parent, String name) => parent.find(name);

    final directStatuses = await child(selected, '.Statuses');
    if (directStatuses != null && directStatuses.isDirectory) return directStatuses;

    final mediaDir = await child(selected, 'Media');
    if (mediaDir != null && mediaDir.isDirectory) {
      final statuses = await child(mediaDir, '.Statuses');
      if (statuses != null && statuses.isDirectory) return statuses;
    }

    final whatsappDir = await child(selected, 'WhatsApp');
    if (whatsappDir != null && whatsappDir.isDirectory) {
      final media = await child(whatsappDir, 'Media');
      final statuses = media == null ? null : await child(media, '.Statuses');
      if (statuses != null && statuses.isDirectory) return statuses;
    }

    final businessDir = await child(selected, 'WhatsApp Business');
    if (businessDir != null && businessDir.isDirectory) {
      final media = await child(businessDir, 'Media');
      final statuses = media == null ? null : await child(media, '.Statuses');
      if (statuses != null && statuses.isDirectory) return statuses;
    }

    final androidDir = await child(selected, 'Android');
    final mediaRoot = androidDir == null ? await child(selected, 'media') : await child(androidDir, 'media');
    if (mediaRoot != null && mediaRoot.isDirectory) {
      for (final packageName in ['com.whatsapp', 'com.whatsapp.w4b']) {
        final packageDir = await child(mediaRoot, packageName);
        if (packageDir == null || !packageDir.isDirectory) continue;
        for (final appDirName in ['WhatsApp', 'WhatsApp Business']) {
          final appDir = await child(packageDir, appDirName);
          if (appDir == null || !appDir.isDirectory) continue;
          final media = await child(appDir, 'Media');
          if (media == null || !media.isDirectory) continue;
          final statuses = await child(media, '.Statuses');
          if (statuses != null && statuses.isDirectory) return statuses;
        }
      }
    }

    return null;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    if (_accessMode == AccessMode.directPermission) {
      final statuses = await _tryDirectPermissionFlow(showErrors: true);
      if (statuses != null) {
        _setDirectState(statuses);
      }
    } else if (_selectedDirectory != null) {
      await _loadSafStatuses(_selectedDirectory!, saveSelection: false);
    }

    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _enableDirectPermissionMode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final statuses = await _tryDirectPermissionFlow(showErrors: true);
    if (statuses != null) {
      _setDirectState(statuses);
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _clearSavedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTreeUriKey);
    if (!mounted) return;
    setState(() {
      _selectedDirectory = null;
      _statusesDirectory = null;
      _accessMode = null;
      _allStatuses = const [];
      _error = null;
      _folderHint = null;
      _loading = false;
      _previewFutures.clear();
    });
  }

  List<StatusItem> _statusesForCurrentTab() {
    switch (_tabController.index) {
      case 1:
        return _allStatuses.where((item) => item.isImage).toList();
      case 2:
        return _allStatuses.where((item) => item.isVideo).toList();
      default:
        return _allStatuses;
    }
  }

  Future<File?> _previewFile(StatusItem item) {
    return _previewFutures.putIfAbsent(item.id, item.previewFile);
  }

  Future<void> _saveStatus(StatusItem item) async {
    try {
      final file = await item.cacheFile();
      if (file == null) throw 'File unavailable';

      if (item.isVideo) {
        await Gal.putVideo(file.path, album: _galleryAlbumName);
      } else {
        await Gal.putImage(file.path, album: _galleryAlbumName);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.typeLabel} gallery me save ho gaya.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _shareStatus(StatusItem item) async {
    try {
      await item.share();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _openPreview(StatusItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StatusPreviewPage(item: item)),
    );
  }
  @override
  Widget build(BuildContext context) {
    final statuses = _statusesForCurrentTab();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF134E4A), Color(0xFFF6F3EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .34, .34],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WhatsApp Status Saver',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Direct permission first, SAF fallback for Android 11+',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshing ? null : _refresh,
                          icon: _refreshing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Access Mode',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _accessMode == AccessMode.directPermission
                                ? 'Direct permission mode active'
                                : _accessMode == AccessMode.saf
                                    ? 'SAF folder mode active'
                                    : 'Abhi access mode select nahi hua',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF475569),
                                ),
                          ),
                          if (_statusesDirectory != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Status folder: ${_statusesDirectory!.name}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                          if (_folderHint != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _folderHint!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF0F766E),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _loading ? null : _enableDirectPermissionMode,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F766E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Allow Permission'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _selectingFolder ? null : _pickFolder,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Pick Folder'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _clearSavedFolder,
                              child: const Text('Reset Access'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF6F3EA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF0F172A),
                        unselectedLabelColor: const Color(0xFF64748B),
                        indicatorColor: const Color(0xFF0F766E),
                        onTap: (_) => setState(() {}),
                        tabs: const [
                          Tab(text: 'All'),
                          Tab(text: 'Images'),
                          Tab(text: 'Videos'),
                        ],
                      ),
                      Expanded(child: _buildBody(statuses)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<StatusItem> statuses) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _allStatuses.isEmpty) {
      return _EmptyState(
        title: 'Access required',
        message: _error!,
        buttonLabel: 'Pick Folder',
        onPressed: _pickFolder,
      );
    }

    if (statuses.isEmpty) {
      return _EmptyState(
        title: 'No statuses',
        message: 'Permission ya folder access ke baad bhi abhi koi visible status nahi mila.',
        buttonLabel: 'Refresh',
        onPressed: _refresh,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: statuses.length,
      itemBuilder: (context, index) {
        final item = statuses[index];
        return _StatusCard(
          item: item,
          previewFuture: _previewFile(item),
          onOpen: () => _openPreview(item),
          onSave: () => _saveStatus(item),
          onShare: () => _shareStatus(item),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.item,
    required this.previewFuture,
    required this.onOpen,
    required this.onSave,
    required this.onShare,
  });

  final StatusItem item;
  final Future<File?> previewFuture;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: FutureBuilder<File?>(
                          future: previewFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState != ConnectionState.done) {
                              return Container(
                                color: const Color(0xFFE2E8F0),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            final file = snapshot.data;
                            if (file == null) {
                              return Container(
                                color: const Color(0xFFE2E8F0),
                                child: Icon(
                                  item.isVideo ? Icons.play_circle_fill_rounded : Icons.image_rounded,
                                  size: 44,
                                  color: const Color(0xFF475569),
                                ),
                              );
                            }
                            return Image.file(file, fit: BoxFit.cover);
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                item.modifiedAt == null ? 'Unknown date' : _formatDate(item.modifiedAt!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class StatusPreviewPage extends StatefulWidget {
  const StatusPreviewPage({super.key, required this.item});

  final StatusItem item;

  @override
  State<StatusPreviewPage> createState() => _StatusPreviewPageState();
}

class _StatusPreviewPageState extends State<StatusPreviewPage> {
  File? _file;
  VideoPlayerController? _videoController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final file = await widget.item.cacheFile();
      if (file == null) throw 'Preview file unavailable';

      VideoPlayerController? controller;
      if (widget.item.isVideo) {
        controller = VideoPlayerController.file(file);
        await controller.initialize();
        await controller.setLooping(true);
        await controller.play();
      }

      if (!mounted) return;
      setState(() {
        _file = file;
        _videoController = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.item.typeLabel),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.white))
                : widget.item.isVideo
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : Image.file(_file!, fit: BoxFit.contain),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 74,
              width: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.folder_open_rounded, size: 36, color: Color(0xFF0F766E)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/$year  $hour:$minute $suffix';
}


