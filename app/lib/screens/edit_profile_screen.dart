import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/avatar_controller.dart';
import '../widgets/avatar_thumb.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _picking = false;

  Future<void> _uploadOwnPhoto() async {
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        AvatarController.selected.value = picked.path;
        if (mounted) Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.ink,
        title: Text(t('Edit Profile'), style: AppText.screenTitle.copyWith(color: colors.ink, fontSize: 18)),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Choose an avatar'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
              const SizedBox(height: 14),
              Expanded(
                child: ValueListenableBuilder<String?>(
                  valueListenable: AvatarController.selected,
                  builder: (context, current, _) {
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      // +1 for the "upload your own" tile, shown first.
                      itemCount: AvatarController.options.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _UploadTile(loading: _picking, onTap: _picking ? null : _uploadOwnPhoto);
                        }
                        final asset = AvatarController.options[index - 1];
                        final isSelected = asset == current;
                        return GestureDetector(
                          key: Key('avatarOption_${index - 1}'),
                          onTap: () {
                            AvatarController.selected.value = asset;
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? colors.green : colors.hairline,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: AvatarThumb(source: asset, size: double.infinity),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: DottedBorderCircle(
        color: colors.ink38,
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: colors.ink45),
              )
            : Icon(Icons.add_photo_alternate_outlined, color: colors.ink45, size: 28),
      ),
    );
  }
}

/// A dashed-circle "add" affordance — deliberately distinct from the solid
/// bordered avatar options so it reads as an action, not a choice.
class DottedBorderCircle extends StatelessWidget {
  const DottedBorderCircle({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(color: color),
      child: Center(child: child),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final radius = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 24;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * 3.14159265;
      final sweep = (2 * 3.14159265 / dashCount) * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - paint.strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => oldDelegate.color != color;
}
