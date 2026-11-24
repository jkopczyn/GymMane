import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../gymmin.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';

const kDefaultBanner = AssetImage('assets/img/banner_default.jpg');

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 52});

  static const defaultPhoto = AssetImage('assets/img/profile_default.jpg');

  final double size;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: fit, builder: (context, _) => _avatar(context));

  Widget _avatar(BuildContext context) {
    final gc = context.gc;
    final bytes = fit.profilePhoto;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: gc.bgRaised, shape: BoxShape.circle),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: gc.border),
      ),
      child: !GymMin.photos
          ? Center(child: Icon(PhosphorIconsFill.user, size: size * 0.5, color: gc.textTertiary))
          : Image(
              image: bytes != null ? MemoryImage(bytes) : defaultPhoto,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }
}
