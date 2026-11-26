import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kitatemani/core/utils/phone_number.dart';
import 'package:url_launcher/url_launcher.dart';

/// Aksi manual satu ketukan untuk WhatsApp dan Telepon kontak darurat.
class EmergencyLauncher {
  const EmergencyLauncher();

  Uri buildWhatsAppUri(String phone, String message) {
    final intlPhone = PhoneNumber.toInternational(phone);
    final encodedText = Uri.encodeComponent(message);
    return Uri.parse('https://wa.me/$intlPhone?text=$encodedText');
  }

  Uri buildDialUri(String phone) {
    return Uri(scheme: 'tel', path: phone);
  }

  Future<bool> openWhatsApp(
    BuildContext context, {
    required String phone,
    required String contactName,
    required String message,
  }) async {
    final intlPhone = PhoneNumber.toInternational(phone);
    if (intlPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Nomor WhatsApp untuk $contactName belum valid.'),
          ),
        );
      }
      return false;
    }

    final uri = buildWhatsAppUri(phone, message);
    var launched = false;
    try {
      launched = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
    } on Object {
      launched = false;
    }
    if (!context.mounted) return launched;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          launched
              ? 'Membuka WhatsApp ke $contactName…'
              : 'Popup WhatsApp diblokir atau gagal dibuka. Salin pesan lalu kirim ke $contactName ($phone).',
        ),
      ),
    );
    return launched;
  }

  Future<bool> openDialer(
    BuildContext context, {
    required String phone,
    required String contactName,
  }) async {
    if (phone.trim().isEmpty) return false;
    final uri = buildDialUri(phone);
    var launched = false;
    try {
      launched = await launchUrl(uri);
    } on Object {
      launched = false;
    }
    if (!context.mounted) return launched;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          launched
              ? 'Membuka panggilan ke $contactName…'
              : 'Hubungi $contactName di $phone secara manual.',
        ),
      ),
    );
    return launched;
  }
}
