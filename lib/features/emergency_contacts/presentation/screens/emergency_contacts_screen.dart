import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/core/widgets/student_illustrations.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/controllers/emergency_contacts_controller.dart';
import 'package:kitatemani/features/panic/presentation/controllers/panic_controller.dart';
import 'package:kitatemani/l10n/l10n.dart';

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsControllerProvider);
    final student = ref.watch(studentProfileProvider);

    return Scaffold(
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
                      const KtPageHeader(title: L10n.emergencyContactsTitle),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                          children: [
                            Text(
                              'Kontak di bawah menerima peringatan SOS & lokasi presisi saat kamu menahan Tombol Darurat.',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            const KtInfoBanner(
                              icon: Icons.info_outline_rounded,
                              message:
                                  'Kontak bertanda "Utama" menjadi tujuan prioritas WhatsApp dan panggilan telepon cepat.',
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'GURU BK SEKOLAH',
                              style: AppTextStyles.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.inkSlate,
                              ),
                            ),
                            const SizedBox(height: 8),
                            KtCard(
                              color: AppColors.tintIndigo,
                              borderColor:
                                  AppColors.biruTinta.withValues(alpha: 0.25),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const CharacterAvatar(
                                    kind: CharacterKind.buRinaCounselor,
                                    size: 44,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.counselorName,
                                          style: AppTextStyles.poppins(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${student.counselorPhone} · Guru BK sekolah',
                                          style: AppTextStyles.inter(
                                            fontSize: 12,
                                            color: AppColors.inkSlate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  KtStatusPill.mint(
                                    'Tetap aktif',
                                    icon: Icons.lock_outline_rounded,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'KELUARGA & WALI PILIHANMU (${contacts.length}/5)',
                                    style: AppTextStyles.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.7,
                                      color: AppColors.inkSlate,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: contacts.isEmpty
                                      ? null
                                      : () async {
                                          final primary = ref
                                              .read(
                                                emergencyContactsControllerProvider
                                                    .notifier,
                                              )
                                              .primaryContact;
                                          if (primary == null) return;
                                          final senderName =
                                              student.name.trim().isNotEmpty
                                                  ? student.name.trim()
                                                  : 'Siswa';
                                          final ok = await ref
                                              .read(emergencyLauncherProvider)
                                              .openWhatsApp(
                                                context,
                                                phone: primary.phone,
                                                contactName: primary.name,
                                                message:
                                                    '[Tes Kontak Darurat KitaTemani] Halo ${primary.name}, nomor ini terdaftar sebagai kontak darurat WhatsApp $senderName di aplikasi KitaTemani.',
                                              );
                                          if (ok) {
                                            await ref
                                                .read(
                                                  studentProfileProvider
                                                      .notifier,
                                                )
                                                .markSmsTested();
                                          }
                                        },
                                  icon:
                                      const Icon(Icons.chat_outlined, size: 15),
                                  label: const Text('Tes WA'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (contacts.isEmpty)
                              KtCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.tintMint,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const KitaIllustration(
                                        scene:
                                            IllustrationScene.guardianContacts,
                                        width: 88,
                                        height: 70,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum ada kontak darurat',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.heading3,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tambahkan nomor WhatsApp keluarga atau wali tepercaya agar langsung menerima pesan darurat & koordinat lokasi saat Tombol Darurat ditekan.',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              )
                            else
                              for (final contact in contacts) ...[
                                _ContactCard(contact: contact),
                                const SizedBox(height: 10),
                              ],
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
                    child: AppButton(
                      label: contacts.length >= 5
                          ? 'Maksimal 5 kontak tercapai'
                          : 'Tambah kontak baru',
                      icon: Icons.add_rounded,
                      onPressed: contacts.length >= 5
                          ? null
                          : () {
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.addContact);
                            },
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

class _ContactCard extends ConsumerWidget {
  const _ContactCard({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KtCard(
      borderColor:
          contact.isPrimary ? AppColors.biruTinta : AppColors.borderHairline,
      borderWidth: contact.isPrimary ? 1.5 : 1.1,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  contact.isPrimary ? AppColors.indigoSoft : AppColors.canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              contact.isPrimary
                  ? Icons.star_rounded
                  : Icons.person_outline_rounded,
              color:
                  contact.isPrimary ? AppColors.biruTinta : AppColors.inkSlate,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        style: AppTextStyles.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (contact.isPrimary) ...[
                      const SizedBox(width: 8),
                      KtStatusPill.amber('Utama', icon: Icons.star_rounded),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${contact.phone} · ${contact.roleLabel}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => ref
                          .read(emergencyContactsControllerProvider.notifier)
                          .toggleActive(contact.id, !contact.isActive),
                      child: contact.isActive
                          ? KtStatusPill.mint('WhatsApp Darurat Aktif')
                          : KtStatusPill.indigo('Nonaktif'),
                    ),
                    const Spacer(),
                    if (!contact.isPrimary)
                      IconButton(
                        tooltip: 'Jadikan Utama',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: const Icon(
                          Icons.star_border_rounded,
                          size: 18,
                          color: AppColors.amberText,
                        ),
                        onPressed: () => ref
                            .read(emergencyContactsControllerProvider.notifier)
                            .setPrimary(contact.id),
                      ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.inkSlate,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.addContact,
                          arguments: contact,
                        );
                      },
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.darurat,
                      ),
                      onPressed: () {
                        ref
                            .read(emergencyContactsControllerProvider.notifier)
                            .deleteContact(contact.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
