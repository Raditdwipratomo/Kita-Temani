import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/media_service.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';
import 'package:kitatemani/core/utils/phone_number.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/profile/presentation/widgets/profile_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _shortNameCtrl;
  late final TextEditingController _classCtrl;
  late final TextEditingController _schoolCtrl;
  late final TextEditingController _homeroomCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _parentCtrl;

  late StudentProfile _initial;
  late String _avatarPreset;
  Uint8List? _pickedPhotoBytes;
  bool _clearedPhoto = false;
  late String _gender;
  DateTime? _birthDate;
  late String _educationLevel;

  bool _isSaving = false;
  bool _isPickingPhoto = false;
  bool _allowPop = false;
  String? _validationError;

  static const List<({String code, String label})> _genderOptions = [
    (code: 'L', label: 'Laki-laki'),
    (code: 'P', label: 'Perempuan'),
    (code: 'other', label: 'Tidak disebutkan'),
  ];

  static const List<({String code, String label})> _educationOptions = [
    (code: 'SMP', label: 'SMP / MTs'),
    (code: 'SMA', label: 'SMA / MA'),
    (code: 'SMK', label: 'SMK'),
  ];

  @override
  void initState() {
    super.initState();
    _initial = ref.read(studentProfileProvider);
    _nameCtrl = TextEditingController(text: _initial.name);
    _shortNameCtrl = TextEditingController(text: _initial.shortName);
    _classCtrl = TextEditingController(text: _initial.className);
    _schoolCtrl = TextEditingController(text: _initial.schoolName);
    _homeroomCtrl = TextEditingController(text: _initial.homeroomTeacher);
    _phoneCtrl = TextEditingController(
      text: _initial.phoneNumber.trim().isNotEmpty
          ? PhoneNumber.formatDisplay(_initial.phoneNumber)
          : '',
    );
    _parentCtrl = TextEditingController(text: _initial.parentName);

    _avatarPreset = _initial.avatarPreset;
    _gender = _initial.gender;
    _birthDate = _initial.birthDate;
    _educationLevel = _initial.educationLevel;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortNameCtrl.dispose();
    _classCtrl.dispose();
    _schoolCtrl.dispose();
    _homeroomCtrl.dispose();
    _phoneCtrl.dispose();
    _parentCtrl.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    final initialPhone = _initial.phoneNumber.trim().isNotEmpty
        ? PhoneNumber.formatDisplay(_initial.phoneNumber)
        : '';
    return _nameCtrl.text.trim() != _initial.name.trim() ||
        _shortNameCtrl.text.trim() != _initial.shortName.trim() ||
        _classCtrl.text.trim() != _initial.className.trim() ||
        _schoolCtrl.text.trim() != _initial.schoolName.trim() ||
        _homeroomCtrl.text.trim() != _initial.homeroomTeacher.trim() ||
        _phoneCtrl.text.trim() != initialPhone ||
        _parentCtrl.text.trim() != _initial.parentName.trim() ||
        _avatarPreset != _initial.avatarPreset ||
        _pickedPhotoBytes != null ||
        _clearedPhoto ||
        _gender != _initial.gender ||
        _birthDate != _initial.birthDate ||
        _educationLevel != _initial.educationLevel;
  }

  StudentProfile _buildDraftPreview(StudentProfile base) {
    final encodedPhoto = _clearedPhoto
        ? ''
        : (_pickedPhotoBytes != null
            ? base64Encode(_pickedPhotoBytes!)
            : base.avatarBase64);
    return base.copyWith(
      name: _nameCtrl.text.trim(),
      shortName: _shortNameCtrl.text.trim(),
      className: _classCtrl.text.trim(),
      schoolName: _schoolCtrl.text.trim(),
      homeroomTeacher: _homeroomCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      parentName: _parentCtrl.text.trim(),
      avatarPreset: _avatarPreset,
      avatarBase64: encodedPhoto,
      avatarUrl: _clearedPhoto ? '' : base.avatarUrl,
      gender: _gender,
      birthDate: _birthDate,
      clearBirthDate: _birthDate == null,
      educationLevel: _educationLevel,
    );
  }

  Future<void> _pickAvatarPhoto() async {
    if (_isPickingPhoto || _isSaving) return;
    setState(() => _isPickingPhoto = true);
    try {
      final picked = await ref.read(mediaServiceProvider).pickAvatarImage();
      if (!mounted || picked == null || picked.bytes == null) return;
      setState(() {
        _pickedPhotoBytes = picked.bytes;
        _clearedPhoto = false;
        _validationError = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  void _selectPreset(String presetId) {
    setState(() {
      _avatarPreset = presetId;
      _pickedPhotoBytes = null;
      _clearedPhoto = true;
      _validationError = null;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _birthDate ?? DateTime(now.year - 16, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1955),
      lastDate: now,
    );
    if (selected != null && mounted) {
      setState(() {
        _birthDate = selected;
        _validationError = null;
      });
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var isUpdating = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            final newPass = passCtrl.text;
            final confirmPass = confirmCtrl.text;
            if (newPass.trim().length < 6) {
              setDialogState(
                () => dialogError = 'Kata sandi baru minimal 6 karakter.',
              );
              return;
            }
            if (newPass != confirmPass) {
              setDialogState(
                () => dialogError = 'Konfirmasi kata sandi belum cocok.',
              );
              return;
            }
            setDialogState(() {
              isUpdating = true;
              dialogError = null;
            });
            final res = await ref
                .read(studentProfileProvider.notifier)
                .updatePassword(newPass);
            if (!ctx.mounted) return;
            setDialogState(() => isUpdating = false);
            if (res case Err(:final failure)) {
              setDialogState(() => dialogError = failure.message);
              return;
            }
            Navigator.of(ctx).pop();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Kata sandi berhasil diperbarui.')),
              );
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.cardWhite,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Ubah Kata Sandi', style: AppTextStyles.heading2),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi baru',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Ulangi kata sandi baru',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: AppTextStyles.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darurat,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isUpdating ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isUpdating ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.biruTinta,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                ),
                child: Text(isUpdating ? 'Menyimpan…' : 'Simpan'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      passCtrl.dispose();
      confirmCtrl.dispose();
    });
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final name = _nameCtrl.text.trim();
    final shortName = _shortNameCtrl.text.trim();
    final className = _classCtrl.text.trim();
    final schoolName = _schoolCtrl.text.trim();
    final rawPhone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _validationError = 'Nama lengkap wajib diisi.');
      return;
    }
    if (className.isEmpty) {
      setState(
        () => _validationError = _initial.role.isStaff
            ? 'Ruang atau jabatan wajib diisi.'
            : 'Kelas wajib diisi (contoh: XI-MIPA 2).',
      );
      return;
    }
    if (schoolName.isEmpty) {
      setState(() => _validationError = 'Nama sekolah wajib diisi.');
      return;
    }

    var formattedPhone = '';
    if (rawPhone.isNotEmpty) {
      final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 9 || digits.length > 15) {
        setState(
          () => _validationError =
              'Nomor telepon / WhatsApp harus berisi 9–15 digit angka.',
        );
        return;
      }
      formattedPhone = PhoneNumber.formatDisplay(digits);
    }

    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    final notifier = ref.read(studentProfileProvider.notifier);
    var nextAvatarUrl = _clearedPhoto ? '' : _initial.avatarUrl;
    var nextAvatarBase64 = _clearedPhoto ? '' : _initial.avatarBase64;

    final photoBytes = _pickedPhotoBytes;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      nextAvatarBase64 = base64Encode(photoBytes);
      final uploadRes = await notifier.uploadAvatar(photoBytes);
      if (uploadRes case Ok(:final value)) {
        if (value.isNotEmpty) {
          nextAvatarUrl = value;
        }
      }
    }

    final res = await notifier.saveProfileAndSync(
      name: name,
      shortName: shortName.isNotEmpty ? shortName : name.split(' ').first,
      className: className,
      schoolName: schoolName,
      isProfileCompleted: true,
      avatarPreset: _avatarPreset,
      avatarUrl: nextAvatarUrl,
      avatarBase64: nextAvatarBase64,
      gender: _gender,
      birthDate: _birthDate,
      clearBirthDate: _birthDate == null,
      educationLevel: _educationLevel,
      homeroomTeacher: _homeroomCtrl.text.trim(),
      phoneNumber: formattedPhone,
      parentName: _parentCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res case Err(:final failure)) {
      setState(() => _validationError = failure.message);
      return;
    }

    _allowPop = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil diperbarui.')),
    );
    _exitScreen();
  }

  void _exitScreen() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    unawaited(
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
        arguments: 3,
      ),
    );
  }

  Future<void> _handleBack() async {
    if (_isSaving) return;
    if (!_hasUnsavedChanges) {
      _allowPop = true;
      _exitScreen();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Buang perubahan?', style: AppTextStyles.heading2),
        content: Text(
          'Perubahan profil yang belum disimpan akan hilang.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Lanjut edit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darurat,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('Keluar tanpa simpan'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      _exitScreen();
    }
  }

  TextStyle _fieldLabelStyle() => AppTextStyles.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.inkNavy,
      );

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: AppTextStyles.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppColors.inkSlate,
        ),
      ),
    );
  }

  Widget _buildChoiceChipRow<T>({
    required List<({T code, String label})> options,
    required T selected,
    required ValueChanged<T> onSelect,
    bool allowDeselect = false,
    T? deselectedValue,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt.code == selected;
        return ChoiceChip(
          label: Text(
            opt.label,
            style: AppTextStyles.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.biruTinta : AppColors.inkNavy,
            ),
          ),
          selected: isSelected,
          selectedColor: AppColors.indigoSoft,
          backgroundColor: AppColors.canvas,
          side: BorderSide(
            color: isSelected ? AppColors.biruTinta : AppColors.borderHairline,
            width: isSelected ? 1.4 : 1,
          ),
          showCheckmark: false,
          onSelected: (_) {
            if (isSelected && allowDeselect && deselectedValue != null) {
              onSelect(deselectedValue);
            } else {
              onSelect(opt.code);
            }
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseProfile = ref.watch(studentProfileProvider);
    final preview = _buildDraftPreview(baseProfile);
    final isStaff = baseProfile.role.isStaff;
    final completeness = preview.profileCompletenessPercent;
    final hasCustomPhoto = !_clearedPhoto &&
        (_pickedPhotoBytes != null || baseProfile.hasCustomPhoto);
    final supabaseClient = ref.watch(supabaseClientProvider);
    final providerName =
        supabaseClient?.auth.currentUser?.appMetadata['provider']?.toString();
    final isOAuthGoogle = providerName == 'google';

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        KtPageHeader(
                          title:
                              isStaff ? 'Ubah Profil Guru BK' : 'Ubah Profil',
                          subtitle:
                              'Lengkapi datamu untuk memudahkan pendampingan',
                          onBack: _handleBack,
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            children: [
                              // 1. Avatar & Kelengkapan Profil
                              KtCard(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            ProfileAvatarWidget(
                                              profile: preview,
                                              size: 74,
                                              overridePresetId: _avatarPreset,
                                              overridePhotoBytes:
                                                  _pickedPhotoBytes,
                                              clearPhoto: _clearedPhoto,
                                            ),
                                            Positioned(
                                              right: -4,
                                              bottom: -4,
                                              child: Material(
                                                color: AppColors.biruTinta,
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  onTap: _pickAvatarPhoto,
                                                  customBorder:
                                                      const CircleBorder(),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(6),
                                                    child: Icon(
                                                      Icons.camera_alt_rounded,
                                                      size: 15,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Foto & Avatar Profil',
                                                style: AppTextStyles.poppins(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.inkNavy,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Foto galeri otomatis dibersihkan metadata EXIF-nya.',
                                                style: AppTextStyles.bodySmall,
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 6,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: _isPickingPhoto
                                                        ? null
                                                        : _pickAvatarPhoto,
                                                    icon: const Icon(
                                                      Icons
                                                          .photo_library_outlined,
                                                      size: 16,
                                                    ),
                                                    label: Text(
                                                      _isPickingPhoto
                                                          ? 'Memuat…'
                                                          : 'Pilih Foto',
                                                    ),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          AppColors.biruTinta,
                                                      backgroundColor:
                                                          AppColors.tintIndigo,
                                                      side: BorderSide(
                                                        color: AppColors
                                                            .biruTinta
                                                            .withValues(
                                                                alpha: 0.3),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                      minimumSize:
                                                          const Size(0, 34),
                                                    ),
                                                  ),
                                                  if (hasCustomPhoto)
                                                    TextButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          _pickedPhotoBytes =
                                                              null;
                                                          _clearedPhoto = true;
                                                        });
                                                      },
                                                      style:
                                                          TextButton.styleFrom(
                                                        foregroundColor:
                                                            AppColors.darurat,
                                                        minimumSize:
                                                            const Size(0, 34),
                                                      ),
                                                      child: const Text(
                                                        'Hapus Foto',
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Atau pilih gaya avatar cepat:',
                                      style: _fieldLabelStyle(),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 54,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: kProfileAvatarPresets.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 10),
                                        itemBuilder: (context, index) {
                                          final preset =
                                              kProfileAvatarPresets[index];
                                          final selected = !hasCustomPhoto &&
                                              _avatarPreset == preset.id;
                                          return Tooltip(
                                            message: preset.label,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _selectPreset(preset.id),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(2.5),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: selected
                                                        ? AppColors.biruTinta
                                                        : Colors.transparent,
                                                    width: 2.2,
                                                  ),
                                                ),
                                                child: ProfileAvatarWidget(
                                                  profile: preview,
                                                  size: 44,
                                                  overridePresetId: preset.id,
                                                  clearPhoto: true,
                                                  showShadow: false,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Kelengkapan profil',
                                          style: AppTextStyles.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.inkNavy,
                                          ),
                                        ),
                                        Text(
                                          '$completeness%',
                                          style: AppTextStyles.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: completeness >= 80
                                                ? AppColors.mintText
                                                : AppColors.biruTinta,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: completeness / 100,
                                        minHeight: 7,
                                        backgroundColor: AppColors.indigoSoft,
                                        color: completeness >= 80
                                            ? AppColors.hijau
                                            : AppColors.biruTinta,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 2. Identitas Pribadi
                              _sectionHeader('IDENTITAS PRIBADI'),
                              KtCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nama lengkap *',
                                      style: _fieldLabelStyle(),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _nameCtrl,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      onChanged: (_) => setState(
                                        () => _validationError = null,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Contoh: Radit Pratama',
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Nama panggilan',
                                      style: _fieldLabelStyle(),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _shortNameCtrl,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Dipakai di sapaan Beranda & CurhAI',
                                        prefixIcon: Icon(
                                          Icons.badge_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Jenis kelamin',
                                      style: _fieldLabelStyle(),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildChoiceChipRow<String>(
                                      options: _genderOptions,
                                      selected: _gender,
                                      allowDeselect: true,
                                      deselectedValue: '',
                                      onSelect: (v) =>
                                          setState(() => _gender = v),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Tanggal lahir',
                                      style: _fieldLabelStyle(),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: _pickBirthDate,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 13,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.canvas,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AppColors.borderHairline,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.cake_outlined,
                                              size: 20,
                                              color: AppColors.inkSlate,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _birthDate != null
                                                    ? DateFormatter.fullDate(
                                                        _birthDate!,
                                                      )
                                                    : 'Pilih tanggal lahir (opsional)',
                                                style: AppTextStyles.inter(
                                                  fontSize: 13.5,
                                                  color: _birthDate != null
                                                      ? AppColors.inkNavy
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                            ),
                                            if (_birthDate != null)
                                              InkWell(
                                                onTap: () => setState(
                                                  () => _birthDate = null,
                                                ),
                                                child: const Icon(
                                                  Icons.close_rounded,
                                                  size: 18,
                                                  color: AppColors.inkSlate,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 3. Data Sekolah (Tanpa NIS)
                              _sectionHeader('DATA SEKOLAH'),
                              KtCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isStaff) ...[
                                      Text(
                                        'Jenjang pendidikan',
                                        style: _fieldLabelStyle(),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildChoiceChipRow<String>(
                                        options: _educationOptions,
                                        selected: _educationLevel,
                                        allowDeselect: true,
                                        deselectedValue: '',
                                        onSelect: (v) => setState(
                                          () => _educationLevel = v,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    Text(
                                      'Nama sekolah *',
                                      style: _fieldLabelStyle(),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _schoolCtrl,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      onChanged: (_) => setState(
                                        () => _validationError = null,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Contoh: SMAN 1 Nusantara',
                                        prefixIcon: Icon(
                                          Icons.school_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      isStaff ? 'Ruang / Jabatan *' : 'Kelas *',
                                      style: _fieldLabelStyle(),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _classCtrl,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      onChanged: (_) => setState(
                                        () => _validationError = null,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: isStaff
                                            ? 'Contoh: Ruang BK'
                                            : 'Contoh: XI-MIPA 2 / VIII-B',
                                        prefixIcon: const Icon(
                                          Icons.class_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    if (!isStaff) ...[
                                      const SizedBox(height: 14),
                                      Text(
                                        'Nama wali kelas',
                                        style: _fieldLabelStyle(),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _homeroomCtrl,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          hintText: 'Contoh: Pak Budi Santoso',
                                          prefixIcon: Icon(
                                            Icons.supervisor_account_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 4. Kontak & Preferensi Pendampingan
                              _sectionHeader(
                                'KONTAK & PREFERENSI PENDAMPINGAN',
                              ),
                              KtCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nomor telepon / WhatsApp',
                                      style: _fieldLabelStyle(),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      onChanged: (_) => setState(
                                        () => _validationError = null,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Contoh: 0812-3456-7890',
                                        helperText:
                                            'Memudahkan koordinasi cepat saat pendampingan atau keadaan darurat.',
                                        helperMaxLines: 2,
                                        prefixIcon: Icon(
                                          Icons.phone_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    if (!isStaff) ...[
                                      const SizedBox(height: 14),
                                      Text(
                                        'Nama orang tua / wali',
                                        style: _fieldLabelStyle(),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _parentCtrl,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Contoh: Ibu Sari (Opsional)',
                                          prefixIcon: Icon(
                                            Icons.family_restroom_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 5. Informasi Akun & Keamanan
                              _sectionHeader('INFORMASI AKUN & KEAMANAN'),
                              KtCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.mail_outline_rounded,
                                          size: 20,
                                          color: AppColors.biruTinta,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Email akun',
                                                style: AppTextStyles.bodySmall,
                                              ),
                                              Text(
                                                baseProfile.email
                                                        .trim()
                                                        .isNotEmpty
                                                    ? baseProfile.email
                                                    : 'Belum terhubung ke email',
                                                style: AppTextStyles.poppins(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        KtStatusPill.indigo(
                                          isOAuthGoogle
                                              ? 'Google'
                                              : (baseProfile.email
                                                      .trim()
                                                      .isNotEmpty
                                                  ? 'Email'
                                                  : 'Lokal'),
                                        ),
                                      ],
                                    ),
                                    if (baseProfile.email.trim().isNotEmpty &&
                                        !isOAuthGoogle) ...[
                                      const Divider(height: 22),
                                      OutlinedButton.icon(
                                        onPressed: _showChangePasswordDialog,
                                        icon: const Icon(
                                          Icons.lock_reset_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Ubah kata sandi'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.biruTinta,
                                          side: BorderSide(
                                            color: AppColors.biruTinta
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              const KtInfoBanner(
                                icon: Icons.lock_outline_rounded,
                                message:
                                    'Detail profilmu bersifat rahasia dan hanya dapat dilihat olehmu serta Guru BK sekolah untuk keperluan pendampingan.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.cardWhite,
                  border: Border(
                    top: BorderSide(color: AppColors.borderHairline, width: 1),
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_validationError != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.sosSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.darurat.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 17,
                                    color: AppColors.darurat,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _validationError!,
                                      style: AppTextStyles.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darurat,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          AppButton(
                            label: 'Simpan Perubahan',
                            isLoading: _isSaving,
                            onPressed: _saveProfile,
                          ),
                        ],
                      ),
                    ),
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
