import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/services/audio_recorder_service.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/location_service.dart';
import 'package:kitatemani/core/services/sms_sender.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/controllers/emergency_contacts_controller.dart';
import 'package:kitatemani/features/panic/data/emergency_launcher.dart';
import 'package:kitatemani/features/panic/domain/entities/panic_outcome.dart';
import 'package:kitatemani/features/panic/domain/usecases/activate_panic.dart';

final panicNotifierProvider = Provider<PanicNotifier>((ref) {
  return SupabasePanicNotifier(ref.watch(supabaseClientProvider));
});

final emergencyLauncherProvider = Provider<EmergencyLauncher>((ref) {
  return const EmergencyLauncher();
});

final activatePanicProvider = Provider<ActivatePanic>((ref) {
  return ActivatePanic(
    recorder: ref.watch(audioRecorderServiceProvider),
    location: ref.watch(locationServiceProvider),
    sms: ref.watch(smsSenderProvider),
    contacts: ref.watch(emergencyContactRepositoryProvider),
    notifier: ref.watch(panicNotifierProvider),
    prefs: ref.watch(localPreferencesServiceProvider),
  );
});

class PanicSessionState {
  const PanicSessionState({
    required this.isActive,
    required this.isActivating,
    required this.elapsedSeconds,
    required this.locationLabel,
    required this.messageText,
    required this.whatsappMessage,
    required this.contactDeliveries,
    required this.requireConfirmationDialog,
    this.position,
    this.triggeredAt,
    this.situationTag,
    this.areaHint,
    this.isRefreshingLocation = false,
    this.activeEventId,
  });

  final bool isActive;
  final bool isActivating;
  final int elapsedSeconds;
  final String locationLabel;
  final String messageText;
  final String whatsappMessage;
  final GeoLocationData? position;
  final DateTime? triggeredAt;
  final String? situationTag;
  final String? areaHint;
  final bool isRefreshingLocation;
  final List<ContactSmsState> contactDeliveries;
  final bool requireConfirmationDialog;
  final String? activeEventId;

  bool get hasFailedSms => contactDeliveries.any(
        (c) =>
            c.status == ContactSmsDeliveryStatus.failed ||
            c.status == ContactSmsDeliveryStatus.retrying,
      );

  static const Object _unset = Object();

  PanicSessionState copyWith({
    bool? isActive,
    bool? isActivating,
    int? elapsedSeconds,
    String? locationLabel,
    String? messageText,
    String? whatsappMessage,
    Object? position = _unset,
    DateTime? triggeredAt,
    Object? situationTag = _unset,
    Object? areaHint = _unset,
    bool? isRefreshingLocation,
    List<ContactSmsState>? contactDeliveries,
    bool? requireConfirmationDialog,
    Object? activeEventId = _unset,
  }) {
    return PanicSessionState(
      isActive: isActive ?? this.isActive,
      isActivating: isActivating ?? this.isActivating,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      locationLabel: locationLabel ?? this.locationLabel,
      messageText: messageText ?? this.messageText,
      whatsappMessage: whatsappMessage ?? this.whatsappMessage,
      position: identical(position, _unset)
          ? this.position
          : position as GeoLocationData?,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      situationTag: identical(situationTag, _unset)
          ? this.situationTag
          : situationTag as String?,
      areaHint:
          identical(areaHint, _unset) ? this.areaHint : areaHint as String?,
      isRefreshingLocation: isRefreshingLocation ?? this.isRefreshingLocation,
      contactDeliveries: contactDeliveries ?? this.contactDeliveries,
      requireConfirmationDialog:
          requireConfirmationDialog ?? this.requireConfirmationDialog,
      activeEventId: identical(activeEventId, _unset)
          ? this.activeEventId
          : activeEventId as String?,
    );
  }
}

class PanicController extends Notifier<PanicSessionState> {
  @override
  PanicSessionState build() {
    return const PanicSessionState(
      isActive: false,
      isActivating: false,
      elapsedSeconds: 0,
      locationLabel: 'Menunggu lokasi GPS',
      messageText: '',
      whatsappMessage: '',
      contactDeliveries: [],
      requireConfirmationDialog: true,
    );
  }

  PanicAlertContext _buildAlertContext({
    GeoLocationData? position,
    DateTime? triggeredAt,
    String? situationTag,
    String? areaHint,
  }) {
    final student = ref.read(studentProfileProvider);
    final resolvedName = student.name.trim().isNotEmpty
        ? student.name.trim()
        : (student.shortName.trim().isNotEmpty
            ? student.shortName.trim()
            : 'Siswa');
    return PanicAlertContext(
      studentName: resolvedName,
      className: student.className.trim(),
      schoolName: student.schoolName.trim(),
      triggeredAt: triggeredAt ?? state.triggeredAt ?? DateTime.now(),
      position: position ?? state.position,
      situationTag: situationTag,
      areaHint: areaHint,
    );
  }

  /// Ensures a detailed WhatsApp SOS message is always ready even if
  /// `PanicStatusScreen` is opened directly before `triggerEmergency()`.
  String resolveWhatsAppMessage() {
    if (state.whatsappMessage.trim().isNotEmpty) {
      return state.whatsappMessage;
    }
    final ctx = _buildAlertContext(
      situationTag: state.situationTag,
      areaHint: state.areaHint,
    );
    return PanicMessage.buildWhatsApp(ctx);
  }

  String buildSafeWhatsAppMessage() {
    final ctx = _buildAlertContext(
      triggeredAt: DateTime.now(),
      situationTag: state.situationTag,
      areaHint: state.areaHint,
    );
    return PanicMessage.buildSafeUpdate(ctx);
  }

  void toggleConfirmationMode(bool value) {
    state = state.copyWith(requireConfirmationDialog: value);
  }

  void setSituationTag(String? tag) {
    final normalized = (tag != null && tag.trim().isNotEmpty)
        ? (state.situationTag == tag.trim() ? null : tag.trim())
        : null;
    final ctx = _buildAlertContext(
      situationTag: normalized,
      areaHint: state.areaHint,
    );
    state = state.copyWith(
      situationTag: normalized,
      messageText: PanicMessage.buildSms(ctx),
      whatsappMessage: PanicMessage.buildWhatsApp(ctx),
    );
  }

  void setAreaHint(String? area) {
    final normalized = (area != null && area.trim().isNotEmpty)
        ? (state.areaHint == area.trim() ? null : area.trim())
        : null;
    final ctx = _buildAlertContext(
      situationTag: state.situationTag,
      areaHint: normalized,
    );
    state = state.copyWith(
      areaHint: normalized,
      messageText: PanicMessage.buildSms(ctx),
      whatsappMessage: PanicMessage.buildWhatsApp(ctx),
    );
  }

  Future<bool> refreshLocation({bool showLoading = true}) async {
    if (state.isRefreshingLocation) return false;
    if (showLoading) {
      state = state.copyWith(isRefreshingLocation: true);
    }
    try {
      final pos = await ref
          .read(locationServiceProvider)
          .currentOrLastKnown(timeout: const Duration(seconds: 2));
      final nextPos = pos ?? state.position;
      final ctx = _buildAlertContext(
        position: nextPos,
        situationTag: state.situationTag,
        areaHint: state.areaHint,
      );
      state = state.copyWith(
        isRefreshingLocation: false,
        position: nextPos,
        locationLabel: nextPos?.label ?? 'Lokasi GPS belum tersedia',
        messageText: PanicMessage.buildSms(ctx),
        whatsappMessage: PanicMessage.buildWhatsApp(ctx),
      );
      return pos != null;
    } on Object {
      state = state.copyWith(isRefreshingLocation: false);
      return false;
    }
  }

  void tickSecond() {
    if (!state.isActive) return;
    state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
  }

  Future<void> triggerEmergency() async {
    state = state.copyWith(isActivating: true);
    final student = ref.read(studentProfileProvider);
    final fullName = student.name.trim().isNotEmpty
        ? student.name.trim()
        : (student.shortName.trim().isNotEmpty
            ? student.shortName.trim()
            : 'Siswa');
    try {
      final outcome = await ref.read(activatePanicProvider).call(
            studentName: fullName,
            className: student.className.trim(),
            schoolName: student.schoolName.trim(),
            schoolSlug: student.schoolId,
            counselorPhone: student.counselorPhone,
            situationTag: state.situationTag,
            areaHint: state.areaHint,
          );

      state = state.copyWith(
        isActive: true,
        isActivating: false,
        elapsedSeconds: 0,
        position: outcome.position,
        triggeredAt: outcome.triggeredAt ?? DateTime.now(),
        locationLabel: outcome.position?.label ?? 'Lokasi GPS belum tersedia',
        messageText: outcome.messageText,
        whatsappMessage: outcome.whatsappMessage,
        contactDeliveries: outcome.contactDeliveries,
        activeEventId: outcome.eventId,
      );
    } on Object {
      final fallbackCtx = _buildAlertContext(
        triggeredAt: DateTime.now(),
        situationTag: state.situationTag,
        areaHint: state.areaHint,
      );
      state = state.copyWith(
        isActive: true,
        isActivating: false,
        elapsedSeconds: 0,
        triggeredAt: fallbackCtx.triggeredAt,
        locationLabel: 'Lokasi GPS belum tersedia',
        messageText: PanicMessage.buildSms(fallbackCtx),
        whatsappMessage: PanicMessage.buildWhatsApp(fallbackCtx),
      );
    }
  }

  Future<void> retryContactSms(String contactId, String phone) async {
    final retrying = state.contactDeliveries
        .map(
          (c) => c.contactId == contactId
              ? c.copyWith(status: ContactSmsDeliveryStatus.retrying)
              : c,
        )
        .toList();
    state = state.copyWith(contactDeliveries: retrying);

    final sentOk = await ref
        .read(smsSenderProvider)
        .sendToSingle(phone, state.messageText);

    final resolved = state.contactDeliveries
        .map(
          (c) => c.contactId == contactId
              ? c.copyWith(
                  status: sentOk
                      ? ContactSmsDeliveryStatus.sent
                      : ContactSmsDeliveryStatus.failed,
                )
              : c,
        )
        .toList();
    state = state.copyWith(contactDeliveries: resolved);
  }

  Future<void> markSafeAndStop() async {
    final recordedAudioPath =
        await ref.read(audioRecorderServiceProvider).stop();
    await ref.read(panicNotifierProvider).resolveEvent(
          eventId: state.activeEventId,
          localAudioPath: recordedAudioPath,
        );
    state = state.copyWith(
      isActive: false,
      elapsedSeconds: 0,
      situationTag: null,
      areaHint: null,
      activeEventId: null,
    );
  }
}

final panicControllerProvider =
    NotifierProvider<PanicController, PanicSessionState>(
  PanicController.new,
);
