import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// صفحة الكاميرا — مكان محجوز، سيُبنى لاحقاً.
class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الكاميرا')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_outlined, size: 64, color: AppColors.muted),
            SizedBox(height: 12),
            Text('قريباً…', style: TextStyle(fontSize: 16, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
