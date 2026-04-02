import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImagePreviewScreen extends StatefulWidget {
  final List<File> files;
  final int initialIndex;
  final Function(File) onSave;
  final Function(File) onShare;

  const ImagePreviewScreen({
    super.key,
    required this.files,
    required this.initialIndex,
    required this.onSave,
    required this.onShare,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.files.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () => widget.onShare(widget.files[_currentIndex]),
          ),
          IconButton(
            icon: const Icon(Icons.save_alt_rounded, color: Color(0xFF25D366)),
            onPressed: () => widget.onSave(widget.files[_currentIndex]),
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.files.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        builder: (ctx, i) {
          return PhotoViewGalleryPageOptions(
            imageProvider: FileImage(widget.files[i]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: PhotoViewHeroAttributes(tag: widget.files[i].path),
          );
        },
        loadingBuilder: (ctx, event) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF25D366)),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomBtn(
              icon: Icons.share_rounded,
              label: 'Share',
              color: Colors.blue,
              onTap: () => widget.onShare(widget.files[_currentIndex]),
            ),
            _BottomBtn(
              icon: Icons.save_alt_rounded,
              label: 'Save',
              color: const Color(0xFF25D366),
              onTap: () => widget.onSave(widget.files[_currentIndex]),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BottomBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}