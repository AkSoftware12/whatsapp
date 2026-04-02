import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';

import '../ImagePreviewScreen/imagepreview.dart';
import '../StatusHelper/status_helper.dart';

class ImageStatusScreen extends StatefulWidget {
  const ImageStatusScreen({super.key});

  @override
  State<ImageStatusScreen> createState() => _ImageStatusScreenState();
}

class _ImageStatusScreenState extends State<ImageStatusScreen> {
  List<File> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    List<File> images = await StatusHelper.getImageStatuses();
    setState(() {
      _images = images;
      _loading = false;
    });
  }

  Future<void> _saveImage(File file) async {
    try {
      // Local folder mein copy
      Directory savedDir = await StatusHelper.getSavedDirectory();
      String fileName = file.path.split('/').last;
      String newPath = '${savedDir.path}/$fileName';
      await file.copy(newPath);

      // Gallery mein save
      await GallerySaver.saveImage(file.path, albumName: 'Status Saver');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Image Gallery mein Save ho gayi! ✅'),
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareImage(File file) async {
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
            Text('Images load ho rahi hain...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_images.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadImages,
      color: const Color(0xFF25D366),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.image_rounded, color: Color(0xFF25D366), size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_images.length} Images mili',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF128C7E),
                  ),
                ),
                const Spacer(),
                Text(
                  'Pull karke refresh karein',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.75,
              ),
              itemCount: _images.length,
              itemBuilder: (ctx, i) {
                return _ImageStatusCard(
                  file: _images[i],
                  onSave: () => _saveImage(_images[i]),
                  onShare: () => _shareImage(_images[i]),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImagePreviewScreen(
                        files: _images,
                        initialIndex: i,
                        onSave: _saveImage,
                        onShare: _shareImage,
                      ),
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
            Icon(Icons.image_not_supported_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              'Koi Image Status Nahi Mila',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pehle WhatsApp mein kisi ka\nimage status dekhen, phir refresh karein.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], height: 1.6),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadImages,
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

class _ImageStatusCard extends StatelessWidget {
  final File file;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onTap;

  const _ImageStatusCard({
    required this.file,
    required this.onSave,
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
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionBtn(
                        icon: Icons.save_alt_rounded,
                        onTap: onSave,
                        color: const Color(0xFF25D366),
                      ),
                      _ActionBtn(
                        icon: Icons.share_rounded,
                        onTap: onShare,
                        color: Colors.blue,
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
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}