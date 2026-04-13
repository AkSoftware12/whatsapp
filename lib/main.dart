import 'dart:async';
import 'dart:io';

import 'package:docman/docman.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final textTheme = GoogleFonts.poppinsTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp Status Saver',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: textTheme,
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
  const StatusItem({required this.document});

  final DocumentFile document;

  String get name => document.name;
  String get uri => document.uri;
  bool get isVideo => name.toLowerCase().endsWith('.mp4');
  bool get isImage {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  String get typeLabel => isVideo ? 'Video' : 'Image';

  DateTime? get modifiedAt => document.lastModifiedDate;
}

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
  bool _selectingFolder = false;
  bool _refreshing = false;
  String? _error;
  DocumentFile? _selectedDirectory;
  DocumentFile? _statusesDirectory;
  List<StatusItem> _allStatuses = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    unawaited(_restoreLastFolder());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _restoreLastFolder() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUri = prefs.getString(_prefsTreeUriKey);
      if (savedUri == null || savedUri.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final restored = await DocumentFile(uri: savedUri).get();
      if (restored == null || !restored.exists || !restored.isDirectory) {
        await prefs.remove(_prefsTreeUriKey);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Saved folder access expire ho gaya. Folder dobara select karo.';
        });
        return;
      }

      await _loadStatusesFromDirectory(restored, saveSelection: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Folder restore nahi hua: $error';
      });
    }
  }

  Future<void> _pickFolder() async {
    if (_selectingFolder) return;

    setState(() {
      _selectingFolder = true;
      _error = null;
    });

    try {
      final picked = await DocMan.pick.directory(
        initDir: _selectedDirectory?.uri,
      );

      if (picked == null) {
        if (!mounted) return;
        setState(() => _selectingFolder = false);
        return;
      }

      await _loadStatusesFromDirectory(picked, saveSelection: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectingFolder = false;
        _loading = false;
        _error = 'Folder select karte waqt issue aaya: $error';
      });
    }
  }

  Future<void> _loadStatusesFromDirectory(
    DocumentFile selected, {
    required bool saveSelection,
  }) async {
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
          _error = '`.Statuses` folder nahi mila. `WhatsApp/Media` ya `WhatsApp Business/Media` folder select karo.';
        });
        return;
      }

      final files = await statusesDir.listDocuments(
        extensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4'],
      );

      final statuses = files
          .where((file) => file.isFile)
          .where((file) => !file.name.startsWith('.'))
          .map((file) => StatusItem(document: file))
          .toList()
        ..sort((a, b) => b.document.lastModified.compareTo(a.document.lastModified));

      if (saveSelection) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsTreeUriKey, selected.uri);
      }

      _previewFutures.clear();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _selectedDirectory = selected;
        _statusesDirectory = statusesDir;
        _allStatuses = statuses;
        _error = statuses.isEmpty
            ? 'Status folder mil gaya, lekin abhi koi visible status nahi hai.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Statuses load nahi huye: $error';
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
      final consumerDirs = <String, String>{
        'com.whatsapp': 'WhatsApp',
        'com.whatsapp.w4b': 'WhatsApp Business',
      };

      for (final entry in consumerDirs.entries) {
        final packageDir = await child(mediaRoot, entry.key);
        if (packageDir == null || !packageDir.isDirectory) continue;
        final appDir = await child(packageDir, entry.value);
        if (appDir == null || !appDir.isDirectory) continue;
        final media = await child(appDir, 'Media');
        if (media == null || !media.isDirectory) continue;
        final statuses = await child(media, '.Statuses');
        if (statuses != null && statuses.isDirectory) return statuses;
      }
    }

    return null;
  }

  List<StatusItem> _statusesForTab() {
    switch (_tabController.index) {
      case 1:
        return _allStatuses.where((item) => item.isImage).toList();
      case 2:
        return _allStatuses.where((item) => item.isVideo).toList();
      default:
        return _allStatuses;
    }
  }

  Future<void> _refreshStatuses() async {
    if (_selectedDirectory == null || _refreshing) return;
    setState(() => _refreshing = true);
    await _loadStatusesFromDirectory(_selectedDirectory!, saveSelection: false);
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _saveStatus(StatusItem item) async {
    try {
      final cachedFile = await item.document.cache();
      if (cachedFile == null) {
        throw 'Temporary file create nahi hua';
      }

      if (item.isVideo) {
        await Gal.putVideo(cachedFile.path, album: _galleryAlbumName);
      } else {
        await Gal.putImage(cachedFile.path, album: _galleryAlbumName);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.typeLabel} gallery me save ho gaya.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $error')),
      );
    }
  }

  Future<void> _shareStatus(StatusItem item) async {
    try {
      await item.document.share(title: 'Share status');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $error')),
      );
    }
  }

  Future<void> _openPreview(StatusItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StatusPreviewPage(item: item)),
    );
  }

  Future<void> _clearFolderAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTreeUriKey);
    if (!mounted) return;
    setState(() {
      _selectedDirectory = null;
      _statusesDirectory = null;
      _allStatuses = const [];
      _previewFutures.clear();
      _error = null;
      _loading = false;
    });
  }

  Future<File?> _previewFile(StatusItem item) {
    return _previewFutures.putIfAbsent(item.uri, () async {
      if (item.isVideo) {
        return item.document.thumbnailFile(width: 512, height: 512, quality: 80);
      }
      return item.document.cache(imageQuality: 80);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabItems = _statusesForTab();

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
                          child: const Icon(Icons.auto_awesome_mosaic_rounded,
                              color: Colors.white),
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
                                'SAF based access, no broad storage permission',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshing ? null : _refreshStatuses,
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
                            'Folder Access',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedDirectory == null
                                ? 'WhatsApp `Media` folder ek baar select karo. App persisted SAF access use karega.'
                                : 'Selected: ${_selectedDirectory!.name}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF475569),
                                ),
                          ),
                          if (_statusesDirectory != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Statuses path: ${_statusesDirectory!.name}',
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
                                  onPressed: _selectingFolder ? null : _pickFolder,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F766E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(_selectedDirectory == null
                                      ? 'Select Folder'
                                      : 'Change Folder'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: _selectedDirectory == null ? null : _clearFolderAccess,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Reset'),
                              ),
                            ],
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
                      Expanded(
                        child: _buildBody(tabItems),
                      ),
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

    if (_selectedDirectory == null) {
      return _EmptyState(
        title: 'Folder select karo',
        message:
            'Android 11+ me hidden WhatsApp statuses dekhne ke liye system folder picker se access dena padega.',
        buttonLabel: 'Choose WhatsApp Folder',
        onPressed: _pickFolder,
      );
    }

    if (_error != null && _allStatuses.isEmpty) {
      return _EmptyState(
        title: 'Statuses unavailable',
        message: _error!,
        buttonLabel: 'Pick Again',
        onPressed: _pickFolder,
      );
    }

    if (statuses.isEmpty) {
      return _EmptyState(
        title: 'No statuses',
        message: 'Current tab me koi status item nahi mila. Refresh ya tab change karke dekho.',
        buttonLabel: 'Refresh',
        onPressed: _refreshStatuses,
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
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.typeLabel,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
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
                item.modifiedAt == null
                    ? 'Unknown date'
                    : _formatDate(item.modifiedAt!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
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
      final file = await widget.item.document.cache();
      if (file == null) {
        throw 'Preview file unavailable';
      }

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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : _error != null
                    ? Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      )
                    : widget.item.isVideo
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(_file!, fit: BoxFit.contain),
                          ),
          ),
        ),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
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
