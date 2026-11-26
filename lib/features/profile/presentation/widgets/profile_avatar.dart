import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';

class ProfileAvatarPreset {
  const ProfileAvatarPreset({
    required this.id,
    required this.label,
    required this.colors,
    this.owlMood,
  });

  final String id;
  final String label;
  final List<Color> colors;
  final OwlMood? owlMood;
}

const List<ProfileAvatarPreset> kProfileAvatarPresets = [
  ProfileAvatarPreset(
    id: 'indigo',
    label: 'Biru Utama',
    colors: [Color(0xFF7B83F8), Color(0xFF585FE6)],
  ),
  ProfileAvatarPreset(
    id: 'mint',
    label: 'Hijau Tenang',
    colors: [Color(0xFF34D399), Color(0xFF18A96B)],
  ),
  ProfileAvatarPreset(
    id: 'coral',
    label: 'Koral Hangat',
    colors: [Color(0xFFFB923C), Color(0xFFF97316)],
  ),
  ProfileAvatarPreset(
    id: 'lilac',
    label: 'Ungu Lembut',
    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
  ),
  ProfileAvatarPreset(
    id: 'owl_warm',
    label: 'Maskot Ramah',
    colors: [Color(0xFFEEF0FD), Color(0xFFDDE2FD)],
    owlMood: OwlMood.warm,
  ),
  ProfileAvatarPreset(
    id: 'owl_reassuring',
    label: 'Maskot Tenang',
    colors: [Color(0xFFE2F7EE), Color(0xFFC4EEDC)],
    owlMood: OwlMood.reassuring,
  ),
];

ProfileAvatarPreset resolveProfileAvatarPreset(String id) {
  for (final preset in kProfileAvatarPresets) {
    if (preset.id == id) return preset;
  }
  return kProfileAvatarPresets.first;
}

const int _maxAvatarCacheEntries = 16;
final LinkedHashMap<String, Uint8List> _decodedAvatarCache =
    LinkedHashMap<String, Uint8List>();

Uint8List? tryDecodeAvatarBase64(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final cached = _decodedAvatarCache.remove(trimmed);
  if (cached != null) {
    _decodedAvatarCache[trimmed] = cached;
    return cached;
  }
  try {
    final bytes = base64Decode(trimmed);
    if (bytes.isEmpty) return null;
    if (_decodedAvatarCache.length >= _maxAvatarCacheEntries) {
      _decodedAvatarCache.remove(_decodedAvatarCache.keys.first);
    }
    _decodedAvatarCache[trimmed] = bytes;
    return bytes;
  } on Object {
    return null;
  }
}

class ProfileAvatarWidget extends StatelessWidget {
  const ProfileAvatarWidget({
    required this.profile,
    this.size = 58,
    this.borderRadius,
    this.respectDisguisedMode = false,
    this.showShadow = true,
    this.overridePresetId,
    this.overridePhotoBytes,
    this.clearPhoto = false,
    super.key,
  });

  final StudentProfile profile;
  final double size;
  final double? borderRadius;
  final bool respectDisguisedMode;
  final bool showShadow;
  final String? overridePresetId;
  final Uint8List? overridePhotoBytes;
  final bool clearPhoto;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius;
    final boxShape = radius == null ? BoxShape.circle : BoxShape.rectangle;
    final resolvedRadius =
        radius == null ? null : BorderRadius.circular(radius);

    if (respectDisguisedMode && profile.isDisguisedMode) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.inkNavy,
          shape: boxShape,
          borderRadius: resolvedRadius,
        ),
        child: Center(
          child: Text(
            profile.initials,
            style: AppTextStyles.poppins(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    final preset =
        resolveProfileAvatarPreset(overridePresetId ?? profile.avatarPreset);
    final photoBytes = clearPhoto
        ? null
        : (overridePhotoBytes ?? tryDecodeAvatarBase64(profile.avatarBase64));
    final networkUrl = clearPhoto ? '' : profile.avatarUrl.trim();
    final hasNetworkPhoto =
        networkUrl.startsWith('http://') || networkUrl.startsWith('https://');

    Widget fallbackContent() {
      if (preset.owlMood != null) {
        return Center(
          child: OwlMascot(
            mood: preset.owlMood!,
            size: size * 0.84,
            showContainer: false,
          ),
        );
      }
      return Center(
        child: Text(
          profile.initials,
          style: AppTextStyles.poppins(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    final rawCachePx = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final cachePx = rawCachePx > 0 ? rawCachePx : null;
    final Widget innerChild;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      innerChild = Image.memory(
        photoBytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallbackContent(),
      );
    } else if (hasNetworkPhoto) {
      innerChild = Image.network(
        networkUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallbackContent(),
      );
    } else {
      innerChild = fallbackContent();
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: boxShape,
        borderRadius: resolvedRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: preset.colors,
        ),
        boxShadow: showShadow ? AppColors.buttonShadow : null,
      ),
      child: innerChild,
    );
  }
}
