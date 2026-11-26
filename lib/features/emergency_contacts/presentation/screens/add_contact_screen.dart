import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/controllers/emergency_contacts_controller.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({
    this.existingContact,
    super.key,
  });

  final EmergencyContact? existingContact;

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String _selectedRole = 'Orang Tua';
  bool _isPrimary = false;
  String? _validationError;

  static const List<String> _roles = [
    'Orang Tua',
    'Wali kelas',
    'Guru BK',
    'Saudara',
    'Teman Dekat',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingContact;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _selectedRole = existing?.roleLabel ?? 'Orang Tua';
    _isPrimary = existing?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showValidationError(String message) {
    setState(() => _validationError = message);
  }

  void _clearValidationError() {
    if (_validationError != null) {
      setState(() => _validationError = null);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showValidationError('Nama dan nomor HP wajib diisi');
      return;
    }

    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 8) {
      _showValidationError('Nomor HP tidak valid (minimal 8 digit)');
      return;
    }

    _clearValidationError();
    final contact = EmergencyContact(
      id: widget.existingContact?.id ??
          'contact-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phone: phone,
      roleLabel: _selectedRole,
      isPrimary: _isPrimary,
      isActive: widget.existingContact?.isActive ?? true,
    );
    final res = await ref
        .read(emergencyContactsControllerProvider.notifier)
        .saveContact(contact);

    if (!mounted) return;
    if (res case Err(:final failure)) {
      _showValidationError(failure.message);
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingContact != null;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: KtPageHeader(
                  title: isEditing
                      ? 'Ubah kontak darurat'
                      : 'Tambah kontak darurat',
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Text(
                        'NAMA KONTAK',
                        style: AppTextStyles.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.inkNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        onChanged: (_) => _clearValidationError(),
                        style: AppTextStyles.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkNavy,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Ayah / Ibu / Wali Kelas',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'HUBUNGAN',
                        style: AppTextStyles.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.inkNavy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _roles.map((role) {
                          final isSelected = _selectedRole == role;
                          return ChoiceChip(
                            label: Text(role),
                            selected: isSelected,
                            showCheckmark: false,
                            selectedColor: AppColors.indigoSoft,
                            backgroundColor: AppColors.cardWhite,
                            labelStyle: AppTextStyles.inter(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.biruTinta
                                  : AppColors.inkNavy,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.biruTinta
                                    : AppColors.borderHairline,
                                width: isSelected ? 1.4 : 1.1,
                              ),
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedRole = role);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'NOMOR TELEPON / WHATSAPP',
                        style: AppTextStyles.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.inkNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        onChanged: (_) => _clearValidationError(),
                        keyboardType: TextInputType.phone,
                        style: AppTextStyles.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkNavy,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: 0812-3456-7890',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      KtCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.amberTint,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: AppColors.amberText,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Jadikan Kontak Utama',
                                    style: AppTextStyles.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Diprioritaskan saat panggilan & chat SOS aktif.',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _isPrimary,
                              activeTrackColor: AppColors.biruTinta,
                              onChanged: (v) => setState(() => _isPrimary = v),
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
                      children: [
                        if (_validationError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.sosSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    AppColors.darurat.withValues(alpha: 0.45),
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
                                      color: AppColors.crimsonContrast,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        AppButton(
                          label: 'Simpan kontak',
                          onPressed: _save,
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
    );
  }
}
