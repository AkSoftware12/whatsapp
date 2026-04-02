import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../ImagePreviewScreen/imagepreview.dart';
import '../StatusHelper/status_helper.dart';
import '../VideoPlayerScreen/videoplayer.dart';


class SavedStatusScreen extends StatefulWidget {
  const SavedStatusScreen({super.key});

  @override
  State<SavedStatusScreen> createState() => _SavedStatusScreenState();
}

class _SavedStatusScreenState extends State<SavedStatusScreen> {
  List<File> _savedFiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    List<File> files = await StatusHelper.getSavedStatuses();
    setState(() {
      _savedFiles = files;
      _loading = false;
    });
  }

  Future<void> _deleteFile(File file) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Karen?'),
        content: const Text('Kya aap is status ko delete karna chahte hain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await file.delete();
      _loadSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File delete ho gayi'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF25D366)),
      );
    }

    if (_savedFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.save_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              const Text(
                'Koi Saved Status Nahi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Images/Videos tab mein jaake\n Save button dabayein',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    List<File> images = _savedFiles.where((f) => StatusHelper.isImage(f.path)).toList();
    List<File> videos = _savedFiles.where((f) => StatusHelper.isVideo(f.path)).toList();

    return RefreshIndicator(
      onRefresh: _loadSaved,
      color: const Color(0xFF25D366),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.save_alt_rounded, color: Color(0xFF25D366), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${_savedFiles.length} Files Saved',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF128C7E),
                    ),
                  ),
                ],
              ),
            ),
            if (images.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '📷 Saved Images',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF128C7E),
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.8,
                ),
                itemCount: images.length,
                itemBuilder: (ctx, i) {
                  return _SavedImageCard(
                    file: images[i],
                    onDelete: () => _deleteFile(images[i]),
                    onShare: () => Share.shareXFiles([XFile(images[i].path)]),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImagePreviewScreen(
                          files: images,
                          initialIndex: i,
                          onSave: (_) {},
                          onShare: (f) => Share.shareXFiles([XFile(f.path)]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            if (videos.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  '🎥 Saved Videos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF128C7E),
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: videos.length,
                itemBuilder: (ctx, i) {
                  return _SavedVideoCard(
                    file: videos[i],
                    index: i + 1,
                    onDelete: () => _deleteFile(videos[i]),
                    onShare: () => Share.shareXFiles([XFile(videos[i].path)]),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(file: videos[i]),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SavedImageCard extends StatelessWidget {
  final File file;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onTap;

  const _SavedImageCard({
    required this.file,
    required this.onDelete,
    required this.onShare,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(file, fit: BoxFit.cover),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onShare,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedVideoCard extends StatelessWidget {
  final File file;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onTap;

  const _SavedVideoCard({
    required this.file,
    required this.index,
    required this.onDelete,
    required this.onShare,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String fileSize = StatusHelper.formatFileSize(file.lengthSync());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.play_circle_fill_rounded,
              size: 32, color: Color(0xFF25D366)),
        ),
        title: Text(
          'Saved Video #$index',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(fileSize,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onShare,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.share_rounded, color: Colors.blue, size: 18),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}