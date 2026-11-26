import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/error/failure.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/media_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/report/data/datasources/report_remote_data_source.dart';
import 'package:kitatemani/features/report/data/repositories/report_repository_impl.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/domain/repositories/report_repository.dart';
import 'package:kitatemani/features/report/domain/usecases/submit_report.dart';
import 'package:uuid/uuid.dart';

String Function() _buildReportUserScopeResolver(Ref ref) {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return () {
    if (disposed) return 'guest';
    final uid = ref.read(supabaseClientProvider)?.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) return uid;
    final profileId = ref.read(studentProfileProvider).id.trim();
    return profileId.isNotEmpty ? profileId : 'guest';
  };
}

final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource>((ref) {
  return ReportRemoteDataSource(ref.watch(supabaseClientProvider));
});

final reportCodeStoreProvider = Provider<ReportCodeStore>((ref) {
  return SecureReportCodeStore(
    ref.watch(secureStorageServiceProvider),
    userScopeResolver: _buildReportUserScopeResolver(ref),
  );
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(
    ref.watch(reportRemoteDataSourceProvider),
    prefs: ref.watch(localPreferencesServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    codeStore: ref.watch(reportCodeStoreProvider),
    userScopeResolver: _buildReportUserScopeResolver(ref),
  );
});

final submitReportProvider = Provider<SubmitReport>((ref) {
  return SubmitReport(
    ref.watch(reportRepositoryProvider),
    ref.watch(reportCodeStoreProvider),
  );
});

enum ReportListFilter {
  semua('Semua'),
  dikirim('Dikirim'),
  dibaca('Dibaca'),
  ditindak('Ditindak'),
  selesai('Selesai');

  const ReportListFilter(this.label);
  final String label;
}

class ReportDraftState {
  const ReportDraftState({
    required this.selectedTypes,
    required this.occurredAt,
    required this.whenLabel,
    required this.location,
    required this.narrative,
    this.perpetratorNames = '',
    this.victimName = '',
    required this.attachments,
    required this.evidenceFiles,
    required this.evidenceLink,
    required this.lastSubmittedCode,
    required this.isSubmitting,
    this.isVictim = true,
    this.errorMessage,
  });

  final bool isVictim;
  final Set<BullyingType> selectedTypes;
  final DateTime occurredAt;
  final String whenLabel;
  final String location;
  final String narrative;
  final String perpetratorNames;
  final String victimName;
  final List<String> attachments;
  final List<EvidenceAttachment> evidenceFiles;
  final String evidenceLink;
  final String? lastSubmittedCode;
  final bool isSubmitting;
  final String? errorMessage;

  ReportDraftState copyWith({
    bool? isVictim,
    Set<BullyingType>? selectedTypes,
    DateTime? occurredAt,
    String? whenLabel,
    String? location,
    String? narrative,
    String? perpetratorNames,
    String? victimName,
    List<String>? attachments,
    List<EvidenceAttachment>? evidenceFiles,
    String? evidenceLink,
    String? lastSubmittedCode,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return ReportDraftState(
      isVictim: isVictim ?? this.isVictim,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      occurredAt: occurredAt ?? this.occurredAt,
      whenLabel: whenLabel ?? this.whenLabel,
      location: location ?? this.location,
      narrative: narrative ?? this.narrative,
      perpetratorNames: perpetratorNames ?? this.perpetratorNames,
      victimName: victimName ?? this.victimName,
      attachments: attachments ?? this.attachments,
      evidenceFiles: evidenceFiles ?? this.evidenceFiles,
      evidenceLink: evidenceLink ?? this.evidenceLink,
      lastSubmittedCode: lastSubmittedCode ?? this.lastSubmittedCode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

class SubmitReportController extends Notifier<ReportDraftState> {
  static const _uuid = Uuid();

  @override
  ReportDraftState build() {
    final defaultDate = DateTime.now();
    return ReportDraftState(
      selectedTypes: const {BullyingType.verbal},
      occurredAt: defaultDate,
      whenLabel: DateFormatter.shortDateYear(defaultDate),
      location: '',
      narrative: '',
      perpetratorNames: '',
      victimName: '',
      attachments: const [],
      evidenceFiles: const [],
      evidenceLink: '',
      lastSubmittedCode: null,
      isSubmitting: false,
    );
  }

  void updateIsVictim(bool isVictim) {
    state = state.copyWith(isVictim: isVictim);
  }

  void toggleType(BullyingType type) {
    final next = Set<BullyingType>.from(state.selectedTypes);
    if (next.contains(type)) {
      if (next.length > 1) {
        next.remove(type);
      }
    } else {
      next.add(type);
    }
    state = state.copyWith(selectedTypes: next);
  }

  void updateOccurredAt(DateTime date) {
    state = state.copyWith(
      occurredAt: date,
      whenLabel: DateFormatter.shortDateYear(date),
    );
  }

  void updateWhen(String whenLabel) {
    state = state.copyWith(whenLabel: whenLabel);
  }

  void updateLocation(String location) {
    state = state.copyWith(location: location);
  }

  void updateNarrative(String narrative) {
    state = state.copyWith(narrative: narrative);
  }

  void updatePerpetratorNames(String perpetratorNames) {
    state = state.copyWith(perpetratorNames: perpetratorNames);
  }

  void updateVictimName(String victimName) {
    state = state.copyWith(victimName: victimName);
  }

  void prefillFromCurhai(String summary) {
    if (summary.trim().isEmpty) return;
    state = state.copyWith(narrative: summary.trim());
  }

  void addAttachment(String fileName) {
    if (state.attachments.contains(fileName)) return;
    state = state.copyWith(
      attachments: [...state.attachments, fileName],
      evidenceFiles: [
        ...state.evidenceFiles,
        EvidenceAttachment.fromJson(fileName),
      ],
    );
  }

  void addPickedEvidence(PickedEvidence evidence) {
    if (state.attachments.contains(evidence.fileName)) return;
    state = state.copyWith(
      attachments: [...state.attachments, evidence.fileName],
      evidenceFiles: [
        ...state.evidenceFiles,
        EvidenceAttachment(
          fileName: evidence.fileName,
          kind: evidence.kind.wireValue,
          localPath: evidence.localPath,
          bytes: evidence.bytes,
          sizeBytes: evidence.sizeBytes ?? evidence.bytes?.length,
          exifStripped: evidence.exifStripped,
        ),
      ],
    );
  }

  void removeAttachment(String fileName) {
    state = state.copyWith(
      attachments: state.attachments.where((a) => a != fileName).toList(),
      evidenceFiles:
          state.evidenceFiles.where((a) => a.fileName != fileName).toList(),
    );
  }

  void updateEvidenceLink(String link) {
    state = state.copyWith(evidenceLink: link);
  }

  Future<Result<String>> submitCurrentDraft() async {
    state = state.copyWith(isSubmitting: true);
    final student = ref.read(studentProfileProvider);
    final resolvedLocation =
        state.location.trim().isEmpty ? 'Area Sekolah' : state.location.trim();
    final narrativeText = state.narrative.trim().isEmpty
        ? 'Kejadian bullying di $resolvedLocation pada ${state.whenLabel} yang dilaporkan secara privat dan rahasia kepada Guru BK.'
        : state.narrative.trim();

    final draft = NewReport(
      idempotencyKey: _uuid.v4(),
      schoolId: student.schoolId,
      types: state.selectedTypes,
      occurredAt: state.occurredAt,
      whenLabel: state.whenLabel,
      location: resolvedLocation,
      narrative: narrativeText,
      perpetratorNames: state.perpetratorNames.trim(),
      victimName: state.victimName.trim(),
      reporterName: student.name.trim(),
      reporterClass: student.className.trim(),
      reporterPhone: student.phoneNumber.trim(),
      isVictim: state.isVictim,
      isAnonymous: student.isPrivateMode,
      attachments: state.attachments,
      evidenceFiles: state.evidenceFiles,
      evidenceLink:
          state.evidenceLink.trim().isEmpty ? null : state.evidenceLink.trim(),
    );

    final result = await ref.read(submitReportProvider).call(draft);
    if (result case Ok(:final value)) {
      await ref.read(myReportsControllerProvider.notifier).refresh();
      state = state.copyWith(
        isSubmitting: false,
        lastSubmittedCode: value,
        location: '',
        narrative: '',
        perpetratorNames: '',
        victimName: '',
        attachments: const [],
        evidenceFiles: const [],
        evidenceLink: '',
      );
      return Ok(value);
    } else if (result case Err(:final failure)) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: failure.message,
      );
      return Err(failure);
    }
    return const Err(ServerFailure('Gagal mengirim laporan.'));
  }
}

final submitReportControllerProvider =
    NotifierProvider<SubmitReportController, ReportDraftState>(
  SubmitReportController.new,
);

class MyReportsState {
  const MyReportsState({
    required this.reports,
    required this.filter,
    this.isLoading = false,
  });

  final List<AnonymousReportItem> reports;
  final ReportListFilter filter;
  final bool isLoading;

  List<AnonymousReportItem> get filteredReports {
    return switch (filter) {
      ReportListFilter.semua => reports,
      ReportListFilter.dikirim =>
        reports.where((r) => r.status == ReportStatus.diterima).toList(),
      ReportListFilter.dibaca =>
        reports.where((r) => r.status == ReportStatus.ditinjau).toList(),
      ReportListFilter.ditindak =>
        reports.where((r) => r.status == ReportStatus.tindakLanjut).toList(),
      ReportListFilter.selesai =>
        reports.where((r) => r.status.isCompleted).toList(),
    };
  }

  AnonymousReportItem get featuredReport => reports.firstWhere(
        (r) => !r.status.isCompleted,
        orElse: () => reports.first,
      );
}

class MyReportsController extends Notifier<MyReportsState> {
  bool _disposed = false;
  int _buildGen = 0;

  @override
  MyReportsState build() {
    _disposed = false;
    final gen = ++_buildGen;
    ref.onDispose(() => _disposed = true);
    ref.watch(
      studentProfileProvider.select((p) => (id: p.id, role: p.role)),
    );
    Future.microtask(() => refresh(expectedGen: gen));
    return const MyReportsState(
      reports: [],
      filter: ReportListFilter.semua,
      isLoading: true,
    );
  }

  Future<void> refresh({int? expectedGen}) async {
    if (_disposed) return;
    if (expectedGen != null && expectedGen != _buildGen) return;
    final activeGen = expectedGen ?? _buildGen;
    final repo = ref.read(reportRepositoryProvider);
    final student = ref.read(studentProfileProvider);
    final expectedId = student.id;
    final expectedRole = student.role;
    final list = expectedRole.isStaff
        ? await repo.getSchoolReports()
        : await repo.getMyReports();
    if (_disposed || activeGen != _buildGen) return;
    final current = ref.read(studentProfileProvider);
    if (current.id != expectedId || current.role != expectedRole) {
      return;
    }
    state = MyReportsState(
      reports: list,
      filter: state.filter,
      isLoading: false,
    );
  }

  void setFilter(ReportListFilter filter) {
    state = MyReportsState(
      reports: state.reports,
      filter: filter,
    );
  }

  Future<void> simulateStatusUpdate(
    String code, {
    ReportStatus? nextStatus,
    String? note,
  }) async {
    final res = await ref.read(reportRepositoryProvider).advanceReportStatus(
          code,
          nextStatus: nextStatus,
          note: note,
        );
    if (res case Ok(:final value)) {
      state = MyReportsState(
        reports: value,
        filter: state.filter,
      );
    }
  }

  Future<Result<void>> updateReportStatus(
    String code, {
    required ReportStatus nextStatus,
    String? note,
  }) async {
    final res = await ref.read(reportRepositoryProvider).advanceReportStatus(
          code,
          nextStatus: nextStatus,
          note: note,
        );
    if (res case Ok(:final value)) {
      state = MyReportsState(
        reports: value,
        filter: state.filter,
      );
      return const Ok(null);
    } else if (res case Err(:final failure)) {
      return Err(failure);
    }
    return const Err(ServerFailure('Gagal memperbarui status laporan.'));
  }
}

final myReportsControllerProvider =
    NotifierProvider<MyReportsController, MyReportsState>(
  MyReportsController.new,
);
