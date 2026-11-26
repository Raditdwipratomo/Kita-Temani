import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/core/services/audio_recorder_service.dart';
import 'package:kitatemani/core/services/location_service.dart';
import 'package:kitatemani/core/services/sms_sender.dart';
import 'package:kitatemani/features/emergency_contacts/data/repositories/emergency_contact_repository_impl.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/panic/data/emergency_launcher.dart';
import 'package:kitatemani/features/panic/domain/entities/panic_outcome.dart';
import 'package:kitatemani/features/panic/domain/usecases/activate_panic.dart';

void main() {
  group('ActivatePanic UseCase', () {
    test('continues audio and counselor notification even if SMS fails',
        () async {
      final recorder = DummyAudioRecorderService();
      final location = DummyLocationService();
      final sms = DummySmsSender()..simulateFailure = true;
      final contacts = DummyEmergencyContactRepository();
      await contacts.saveContact(
        const EmergencyContact(
          id: '',
          name: 'Wali Uji',
          roleLabel: 'Orang Tua',
          phone: '08123456789',
          isActive: true,
          isPrimary: true,
        ),
      );
      final notifier = DummyPanicNotifier();

      final useCase = ActivatePanic(
        recorder: recorder,
        location: location,
        sms: sms,
        contacts: contacts,
        notifier: notifier,
      );

      final outcome = await useCase(
        studentName: 'Radit Dwi',
        className: 'XI-1',
        schoolName: 'SMAN 2 Bandung',
        situationTag: 'Diancam / diikuti',
        areaHint: 'Koridor / Tangga',
      );

      expect(recorder.isRecording, isTrue);
      expect(outcome.anySmsFailed, isTrue);
      expect(
        outcome.steps.firstWhere((s) => s.step == 'audio').succeeded,
        isTrue,
      );
      expect(
        outcome.steps.firstWhere((s) => s.step == 'notify').succeeded,
        isTrue,
      );
      expect(
        outcome.steps.firstWhere((s) => s.step == 'sms').succeeded,
        isFalse,
      );
      expect(outcome.whatsappMessage, contains('*Nama:* Radit Dwi'));
      expect(outcome.whatsappMessage, contains('*Kelas:* XI-1'));
      expect(outcome.whatsappMessage, contains('*Sekolah:* SMAN 2 Bandung'));
      expect(outcome.whatsappMessage, contains('*Situasi:* Diancam / diikuti'));
      expect(outcome.whatsappMessage, contains('*Area:* Koridor / Tangga'));
      expect(
        outcome.whatsappMessage,
        contains('*Lokasi GPS:* https://maps.google.com/?q=-6.2088,106.8456\n'),
      );
      expect(outcome.whatsappMessage, isNot(contains('±')));
      expect(outcome.messageText, contains('Radit Dwi (XI-1, SMAN 2 Bandung)'));
    });
  });

  group('PanicMessage & EmergencyLauncher', () {
    test('buildWhatsApp omits blank optional fields cleanly', () {
      final msg = PanicMessage.buildWhatsApp(
        PanicAlertContext(
          studentName: 'Radit',
          triggeredAt: DateTime(2026, 11, 21, 22, 19),
        ),
      );

      expect(msg, contains('*Nama:* Radit'));
      expect(msg, isNot(contains('*Kelas:*')));
      expect(msg, isNot(contains('*Sekolah:*')));
      expect(msg, isNot(contains('*Area:*')));
      expect(msg, contains('*Situasi:* Butuh pertolongan segera'));
      expect(msg, contains('*Lokasi GPS:* Belum tersedia'));
      expect(msg, contains('21 Nov 2026, 22:19'));
    });

    test('buildSafeUpdate creates clear confirmation message', () {
      final msg = PanicMessage.buildSafeUpdate(
        PanicAlertContext(
          studentName: 'Radit Dwi',
          className: 'XI-1',
          schoolName: 'SMAN 2 Bandung',
          triggeredAt: DateTime(2026, 11, 21, 22, 25),
        ),
      );

      expect(msg, contains('KONFIRMASI SUDAH AMAN'));
      expect(msg, contains('Radit Dwi (XI-1 · SMAN 2 Bandung)'));
      expect(msg, contains('21 Nov 2026, 22:25'));
    });

    test('buildWhatsAppUri formats Indonesian number and encodes detailed text',
        () {
      const launcher = EmergencyLauncher();
      final uri = launcher.buildWhatsAppUri(
        '089686899447',
        '*Nama:* Radit Dwi\n*Kelas:* XI-1',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/6289686899447');
      expect(uri.queryParameters['text'], '*Nama:* Radit Dwi\n*Kelas:* XI-1');
    });
  });
}
