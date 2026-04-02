import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';

import '../StatusHelper/status_helper.dart';
import '../VideoPlayerScreen/videoplayer.dart';


class VideoStatusScreen extends StatefulWidget {
  const VideoStatusScreen({super.key});

  @override
  State<VideoStatusScreen> createState() => _VideoStatusScreenState();
}

class _VideoStatusScreenState extends State<VideoStatusScreen> {
  List<File> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _loading = true);
    List<File> videos = await StatusHelper.getVideoStatuses();
    setState(() {
      _videos = videos;
      _loading = false;
    });
  }

  Future<void> _saveVideo(File file) async {
    try {
      Directory savedDir = await StatusHelper.getSavedDirectory();
      String fileName = file.path.split('/').last;
      String newPath = '${savedDir.path}/$fileName';
      await file.copy(newPath);

      await GallerySaver.saveVideo(file.path, albumName: 'Status Saver');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Video Gallery mein Save ho gayi! ✅'),
              ],
            ),
            backgroundColor: Color(0xFF25D366),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareVideo(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Status Saver se share kiya');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF25D366)),
            SizedBox(height: 16),
            Text('Videos load ho rahi hain...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      color: const Color(0xFF25D366),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, color: Color(0xFF25D366), size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_videos.length} Videos mili',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF128C7E),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _videos.length,
              itemBuilder: (ctx, i) {
                return _VideoStatusCard(
                  file: _videos[i],
                  index: i + 1,
                  onSave: () => _saveVideo(_videos[i]),
                  onShare: () => _shareVideo(_videos[i]),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(file: _videos[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              'Koi Video Status Nahi Mila',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pehle WhatsApp mein kisi ka\nvideo status dekhen, phir refresh karein.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], height: 1.6),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadVideos,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Karein'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: const BorderSide(color: Color(0xFF25D366)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoStatusCard extends StatelessWidget {
  final File file;
  final int index;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onTap;

  const _VideoStatusCard({
    required this.file,
    required this.index,
    required this.onSave,
    required this.onShare,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    int fileSizeBytes = file.lengthSync();
    String fileSize = StatusHelper.formatFileSize(fileSizeBytes);
    String fileName = file.path.split('/').last;
    DateTime modified = file.lastModifiedSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: onTap,
        leading: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              size: 36,
              color: Color(0xFF25D366),
            ),
          ),
        ),
        title: Text(
          'Video Status #$index',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF128C7E),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(fileSize, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(width: 12),
                Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${modified.day}/${modified.month}/${modified.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBtn(icon: Icons.share_rounded, color: Colors.blue, onTap: onShare),
            const SizedBox(width: 6),
            _IconBtn(icon: Icons.save_alt_rounded, color: const Color(0xFF25D366), onTap: onSave),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}