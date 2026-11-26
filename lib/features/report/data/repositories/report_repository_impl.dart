import 'dart:math';

import 'package:kitatemani/core/error/failure.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/report/data/datasources/report_remote_data_source.dart';
import 'package:kitatemani/features/report/data/models/report_dto.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/domain/repositories/report_repository.dart';

class SecureReportCodeStore implements ReportCodeStore {
  SecureReportCodeStore(
    this._storage, {
    String Function()? userScopeResolver,
  }) : _userScopeResolver = userScopeResolver;

  final SecureStorageService _storage;
  final String Function()? _userScopeResolver;

  String get _storageKey {
    final scope = _userScopeResolver?.call().trim();
    if (scope == null || scope.isEmpty) return 'report_codes';
    return 'report_codes_v2_$scope';
  }

  @override
  Future<List<String>> readCodes() async {
    final raw = await _storage.read(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(',').where((e) => e.isNotEmpty).toList();
  }

  @override
  Future<void> save(String code) async {
    final key = _storageKey;
    final existing = await readCodes();
    if (!existing.contains(code)) {
      final updated = [code, ...existing].join(',');
      await _storage.write(key, updated);
    }
  }

  Future<void> clearCurrentScope() async {
    await _storage.delete(_storageKey);
  }
}

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(
    this._remote, {
    LocalPreferencesService? prefs,
    ConnectivityService? connectivity,
    ReportCodeStore? codeStore,
    String Function()? userScopeResolver,
  })  : _prefs = prefs ?? LocalPreferencesService(null),
        _connectivity = connectivity ?? DummyConnectivityService(),
        _codeStore = codeStore,
        _userScopeResolver = userScopeResolver;

  final ReportRemoteDataSource _remote;
  final LocalPreferencesService _prefs;
  final ConnectivityService _connectivity;
  final ReportCodeStore? _codeStore;
  final String Function()? _userScopeResolver;

  String? _memoryUserScope;
  List<AnonymousReportItem>? _memoryMyItems;
  List<AnonymousReportItem>? _memorySchoolItems;

  String _resolveUserScope() {
    final remoteUid = _remote.currentUserId?.trim();
    if (remoteUid != null && remoteUid.isNotEmpty) return remoteUid;
    final resolved = _userScopeResolver?.call().trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return 'guest';
  }

  String _reportsCacheKeyFor(String userScope, {bool isSchool = false}) =>
      isSchool
          ? 'kt_reports_v2_school_$userScope'
          : 'kt_reports_v2_my_$userScope';

  String _offlineQueueKeyFor(String userScope) =>
      'kt_offline_report_queue_v2_$userScope';

  String _historyKeyFor(String userScope, String code) =>
      'kt_report_history_${userScope}_$code';

  String _messagesKeyFor(String userScope, String code) =>
      'kt_report_messages_${userScope}_$code';

  void _ensureMemoryScope(String userScope) {
    if (_memoryUserScope != userScope) {
      _memoryUserScope = userScope;
      _memoryMyItems = null;
      _memorySchoolItems = null;
    }
  }

  Future<void> clearLocalCache() async {
    _memoryUserScope = null;
    _memoryMyItems = null;
    _memorySchoolItems = null;
    await _prefs.removeByPrefix('kt_reports_');
    await _prefs.removeByPrefix('kt_offline_report_queue_');
    await _prefs.removeByPrefix('kt_report_history_');
    await _prefs.removeByPrefix('kt_report_messages_');
    final store = _codeStore;
    if (store is SecureReportCodeStore) {
      await store.clearCurrentScope();
    }
  }

  static String defaultTitleForStatus(ReportStatus status) {
    return switch (status) {
      ReportStatus.diterima => 'Laporan Dikirim',
      ReportStatus.ditinjau => 'Laporan Dibaca Guru BK',
      ReportStatus.tindakLanjut => 'Ditindaklanjuti Guru BK',
      ReportStatus.selesai => 'Penanganan Laporan Selesai',
    };
  }

  static String defaultDescForStatus(ReportStatus status) {
    return switch (status) {
      ReportStatus.diterima =>
        'Laporan dikirim secara privat & rahasia ke Guru BK sekolah.',
      ReportStatus.ditinjau =>
        'Guru BK telah membaca detail laporan dan memverifikasi bukti lampiran.',
      ReportStatus.tindakLanjut =>
        'Pendampingan dan tindak lanjut aman sedang dilakukan oleh Guru BK.',
      ReportStatus.selesai =>
        'Kasus telah selesai ditangani Guru BK dan dalam pemantauan berkala.',
    };
  }

  String _generateLocalCode() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final rand = (1000 + Random().nextInt(9000)).toString();
    return 'KT-$mm$dd-$rand';
  }

  Future<List<AnonymousReportItem>> _loadLocalReports({
    String? userScope,
    bool isSchool = false,
  }) async {
    final scope = userScope ?? _resolveUserScope();
    _ensureMemoryScope(scope);
    final memItems = isSchool ? _memorySchoolItems : _memoryMyItems;
    final raw = _prefs.getJsonList(_reportsCacheKeyFor(scope, isSchool: isSchool));
    if (raw.isNotEmpty) {
      final memByCode = <String, AnonymousReportItem>{
        if (memItems != null)
          for (final m in memItems) m.code: m,
      };
      final parsed = raw.map((json) {
        final item = AnonymousReportItem.fromJson(json);
        final mem = memByCode[item.code];
        if (mem != null && mem.evidenceFiles.isNotEmpty) {
          return item.copyWith(evidenceFiles: mem.evidenceFiles);
        }
        return item;
      }).toList();
      if (isSchool) {
        _memorySchoolItems = parsed;
      } else {
        _memoryMyItems = parsed;
      }
      return List<AnonymousReportItem>.from(parsed);
    }
    if (memItems != null) {
      return List<AnonymousReportItem>.from(memItems);
    }
    if (isSchool) {
      _memorySchoolItems = <AnonymousReportItem>[];
    } else {
      _memoryMyItems = <AnonymousReportItem>[];
    }
    return <AnonymousReportItem>[];
  }

  Future<void> _saveLocalReports(
    List<AnonymousReportItem> items, {
    String? userScope,
    bool isSchool = false,
  }) async {
    final scope = userScope ?? _resolveUserScope();
    _ensureMemoryScope(scope);
    final copy = List<AnonymousReportItem>.from(items);
    if (isSchool) {
      _memorySchoolItems = copy;
    } else {
      _memoryMyItems = copy;
    }
    await _prefs.setJsonList(
      _reportsCacheKeyFor(scope, isSchool: isSchool),
      items.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> _appendLocalHistoryEntry(
    String code,
    ReportTimelineEntry entry, {
    String? userScope,
  }) async {
    final scope = userScope ?? _resolveUserScope();
    final key = _historyKeyFor(scope, code);
    final existing =
        _prefs.getJsonList(key).map(ReportTimelineEntry.fromJson).toList();
    final next = [...existing, entry];
    await _prefs.setJsonList(
      key,
      next.map((e) => e.toJson()).toList(),
    );
  }

  AnonymousReportItem _mergeMatchingReport(
    AnonymousReportItem remoteItem,
    AnonymousReportItem localItem,
  ) {
    final chosenStatus = localItem.status.index >= remoteItem.status.index
        ? localItem.status
        : remoteItem.status;
    final chosenFiles = remoteItem.evidenceFiles.isNotEmpty
        ? remoteItem.evidenceFiles
        : localItem.evidenceFiles;
    final chosenPerpetrators = remoteItem.perpetratorNames.trim().isNotEmpty
        ? remoteItem.perpetratorNames
        : localItem.perpetratorNames;
    final chosenVictim = remoteItem.victimName.trim().isNotEmpty
        ? remoteItem.victimName
        : localItem.victimName;
    final chosenReporterName = remoteItem.reporterName.trim().isNotEmpty
        ? remoteItem.reporterName
        : localItem.reporterName;
    final chosenReporterClass = remoteItem.reporterClass.trim().isNotEmpty
        ? remoteItem.reporterClass
        : localItem.reporterClass;
    final chosenReporterPhone = remoteItem.reporterPhone.trim().isNotEmpty
        ? remoteItem.reporterPhone
        : localItem.reporterPhone;
    final chosenReporterEmail = remoteItem.reporterEmail.trim().isNotEmpty
        ? remoteItem.reporterEmail
        : localItem.reporterEmail;
    return remoteItem.copyWith(
      status: chosenStatus,
      perpetratorNames: chosenPerpetrators,
      victimName: chosenVictim,
      reporterName: chosenReporterName,
      reporterClass: chosenReporterClass,
      reporterPhone: chosenReporterPhone,
      reporterEmail: chosenReporterEmail,
      evidenceFiles: chosenFiles,
    );
  }

  List<AnonymousReportItem> _reconcileRemoteWithLocal(
    List<AnonymousReportItem> remote,
    List<AnonymousReportItem> local, {
    bool keepPendingOffline = false,
  }) {
    final localByCode = <String, AnonymousReportItem>{
      for (final item in local) item.code: item,
    };
    final byCode = <String, AnonymousReportItem>{};

    for (final remoteItem in remote) {
      final cached = localByCode[remoteItem.code];
      byCode[remoteItem.code] = cached == null
          ? remoteItem
          : _mergeMatchingReport(remoteItem, cached);
    }

    if (keepPendingOffline) {
      for (final localItem in local) {
        if (localItem.isPendingSync && !byCode.containsKey(localItem.code)) {
          byCode[localItem.code] = localItem;
        }
      }
    }

    final merged = byCode.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  AnonymousReportItem _buildLocalItemFromDraft({
    required String code,
    required NewReport draft,
    required List<EvidenceAttachment> attachments,
    required DateTime createdAt,
    bool isPendingSync = false,
  }) {
    return AnonymousReportItem(
      code: code,
      types: draft.types,
      occurredAt: draft.occurredAt,
      location: draft.location,
      narrative: draft.narrative,
      perpetratorNames: draft.perpetratorNames,
      victimName: draft.victimName,
      reporterName: draft.reporterName,
      reporterClass: draft.reporterClass,
      reporterPhone: draft.reporterPhone,
      status: ReportStatus.diterima,
      createdAt: createdAt,
      attachments: attachments.map((e) => e.fileName).toList(),
      evidenceFiles: attachments,
      evidenceLink: draft.evidenceLink,
      isVictim: draft.isVictim,
      isPendingSync: isPendingSync,
    );
  }

  @override
  Future<Result<String>> submit(NewReport draft) async {
    if (draft.types.isEmpty) {
      return const Err(
        ValidationFailure('Pilih minimal 1 jenis perundungan.'),
      );
    }
    if (draft.narrative.trim().length < 10) {
      return const Err(
        ValidationFailure('Ceritakan kronologi minimal 10 karakter.'),
      );
    }

    final userScope = _resolveUserScope();
    final initialAttachments = draft.evidenceFiles.isNotEmpty
        ? draft.evidenceFiles
        : draft.attachments
            .map((a) => EvidenceAttachment(fileName: a))
            .toList();

    final isConnected = await _connectivity.isConnected;
    if (_remote.isRemoteEnabled && !isConnected) {
      final dto = NewReportDto.fromDomain(
        draft,
        uploadedAttachments: initialAttachments,
      );
      final queueKey = _offlineQueueKeyFor(userScope);
      final queue =
          List<Map<String, dynamic>>.from(_prefs.getJsonList(queueKey));
      queue.add(dto.toQueueJson());
      await _prefs.setJsonList(queueKey, queue);

      final pendingCode = _generateLocalCode();
      final now = DateTime.now();
      final items = await _loadLocalReports(userScope: userScope);
      items.insert(
        0,
        _buildLocalItemFromDraft(
          code: pendingCode,
          draft: draft,
          attachments: initialAttachments,
          createdAt: now,
          isPendingSync: true,
        ),
      );
      await _saveLocalReports(items, userScope: userScope);
      await _appendLocalHistoryEntry(
        pendingCode,
        ReportTimelineEntry(
          status: ReportStatus.diterima,
          title: defaultTitleForStatus(ReportStatus.diterima),
          description: defaultDescForStatus(ReportStatus.diterima),
          changedAt: now,
        ),
        userScope: userScope,
      );
      return Ok(pendingCode);
    }

    try {
      final uploaded = await _remote.uploadAttachments(
        reportKey: draft.idempotencyKey,
        items: initialAttachments,
      );
      final dto = NewReportDto.fromDomain(
        draft,
        uploadedAttachments: uploaded,
      );
      final code = await _remote.submit(dto);
      final now = DateTime.now();

      final items = await _loadLocalReports(userScope: userScope);
      final newItem = _buildLocalItemFromDraft(
        code: code,
        draft: draft,
        attachments: uploaded,
        createdAt: now,
      );
      items.insert(0, newItem);
      await _saveLocalReports(items, userScope: userScope);
      await _appendLocalHistoryEntry(
        code,
        ReportTimelineEntry(
          status: ReportStatus.diterima,
          title: defaultTitleForStatus(ReportStatus.diterima),
          description: defaultDescForStatus(ReportStatus.diterima),
          changedAt: now,
        ),
        userScope: userScope,
      );
      await _codeStore?.save(code);
      return Ok(code);
    } on Object catch (e) {
      if (_remote.isRemoteEnabled) {
        final dto = NewReportDto.fromDomain(
          draft,
          uploadedAttachments: initialAttachments,
        );
        final queueKey = _offlineQueueKeyFor(userScope);
        final queue = List<Map<String, dynamic>>.from(
          _prefs.getJsonList(queueKey),
        );
        queue.add(dto.toQueueJson());
        await _prefs.setJsonList(queueKey, queue);
        final fallbackCode = _generateLocalCode();
        final now = DateTime.now();
        final items = await _loadLocalReports(userScope: userScope);
        items.insert(
          0,
          _buildLocalItemFromDraft(
            code: fallbackCode,
            draft: draft,
            attachments: initialAttachments,
            createdAt: now,
            isPendingSync: true,
          ),
        );
        await _saveLocalReports(items, userScope: userScope);
        await _appendLocalHistoryEntry(
          fallbackCode,
          ReportTimelineEntry(
            status: ReportStatus.diterima,
            title: defaultTitleForStatus(ReportStatus.diterima),
            description: defaultDescForStatus(ReportStatus.diterima),
            changedAt: now,
          ),
          userScope: userScope,
        );
        await _codeStore?.save(fallbackCode);
        return Ok(fallbackCode);
      }
      return Err(ServerFailure(e.toString()));
    }
  }

  @override
  Future<int> syncOfflineQueue() async {
    if (!_remote.isRemoteEnabled || !_remote.hasAuthenticatedSession) return 0;
    final connected = await _connectivity.isConnected;
    if (!connected) return 0;

    final userScope = _resolveUserScope();
    final queueKey = _offlineQueueKeyFor(userScope);
    final queue = _prefs.getJsonList(queueKey);
    if (queue.isEmpty) return 0;

    var synced = 0;
    final remaining = <Map<String, dynamic>>[];
    for (final raw in queue) {
      try {
        final dto = NewReportDto.fromQueueJson(raw);
        final code = await _remote.submit(dto);
        await _codeStore?.save(code);
        synced++;
      } on Object {
        remaining.add(raw);
      }
    }
    await _prefs.setJsonList(queueKey, remaining);
    if (synced > 0 && remaining.isEmpty) {
      final local = await _loadLocalReports(userScope: userScope);
      final cleaned = local.where((e) => !e.isPendingSync).toList();
      await _saveLocalReports(cleaned, userScope: userScope);
    }
    return synced;
  }

  @override
  Future<Result<ReportStatus>> statusOf(String code) async {
    final items = await getMyReports();
    for (final item in items) {
      if (item.code == code) return Ok(item.status);
    }
    return const Ok(ReportStatus.diterima);
  }

  @override
  Future<List<AnonymousReportItem>> getMyReports() async {
    final userScope = _resolveUserScope();
    final local = await _loadLocalReports(userScope: userScope);
    if (_remote.isRemoteEnabled &&
        _remote.hasAuthenticatedSession &&
        await _connectivity.isConnected) {
      try {
        await syncOfflineQueue();
        final refreshedLocal = await _loadLocalReports(userScope: userScope);
        final storedCodes = await _codeStore?.readCodes() ?? const <String>[];
        final remote = await _remote.fetchMyReports(storedCodes);
        final reconciled = _reconcileRemoteWithLocal(
          remote,
          refreshedLocal,
          keepPendingOffline: true,
        );
        await _saveLocalReports(reconciled, userScope: userScope);
        return reconciled;
      } on Object {
        // Fallback cleanly to cached reports of the active user scope.
      }
    }
    return local;
  }

  @override
  Future<List<AnonymousReportItem>> getSchoolReports() async {
    final userScope = _resolveUserScope();
    final local = await _loadLocalReports(
      userScope: userScope,
      isSchool: true,
    );
    if (_remote.isRemoteEnabled &&
        _remote.hasAuthenticatedSession &&
        await _connectivity.isConnected) {
      try {
        final remote = await _remote.fetchSchoolReports();
        final reconciled = _reconcileRemoteWithLocal(remote, local);
        await _saveLocalReports(
          reconciled,
          userScope: userScope,
          isSchool: true,
        );
        return reconciled;
      } on Object {
        // Fallback cleanly below.
      }
    }
    return local;
  }

  List<ReportTimelineEntry> _buildFallbackHistory(AnonymousReportItem item) {
    return <ReportTimelineEntry>[
      ReportTimelineEntry(
        status: ReportStatus.diterima,
        title: defaultTitleForStatus(ReportStatus.diterima),
        description: defaultDescForStatus(ReportStatus.diterima),
        changedAt: item.createdAt,
      ),
      if (item.status.index >= ReportStatus.ditinjau.index)
        ReportTimelineEntry(
          status: ReportStatus.ditinjau,
          title: defaultTitleForStatus(ReportStatus.ditinjau),
          description: defaultDescForStatus(ReportStatus.ditinjau),
          changedAt: item.createdAt.add(const Duration(hours: 1)),
        ),
      if (item.status.index >= ReportStatus.tindakLanjut.index)
        ReportTimelineEntry(
          status: ReportStatus.tindakLanjut,
          title: defaultTitleForStatus(ReportStatus.tindakLanjut),
          description: defaultDescForStatus(ReportStatus.tindakLanjut),
          changedAt: item.createdAt.add(const Duration(hours: 3)),
        ),
      if (item.status == ReportStatus.selesai)
        ReportTimelineEntry(
          status: ReportStatus.selesai,
          title: defaultTitleForStatus(ReportStatus.selesai),
          description: defaultDescForStatus(ReportStatus.selesai),
          changedAt: item.createdAt.add(const Duration(days: 1)),
        ),
    ];
  }

  @override
  Future<ReportDetailData> getReportDetail(String code) async {
    final userScope = _resolveUserScope();
    final myReports = await _loadLocalReports(userScope: userScope);
    var localItem = myReports.cast<AnonymousReportItem?>().firstWhere(
          (r) => r?.code == code,
          orElse: () => null,
        );
    if (localItem == null) {
      final schoolReports = await _loadLocalReports(
        userScope: userScope,
        isSchool: true,
      );
      localItem = schoolReports.cast<AnonymousReportItem?>().firstWhere(
            (r) => r?.code == code,
            orElse: () => null,
          );
    }
    final storedHistory = _prefs
        .getJsonList(_historyKeyFor(userScope, code))
        .map(ReportTimelineEntry.fromJson)
        .toList();

    if (_remote.isRemoteEnabled &&
        _remote.hasAuthenticatedSession &&
        await _connectivity.isConnected) {
      try {
        final remoteDetail = await _remote.fetchReportDetail(code);
        if (remoteDetail != null) {
          var effectiveItem = localItem != null &&
                  localItem.status.index > remoteDetail.item.status.index
              ? remoteDetail.item.copyWith(status: localItem.status)
              : remoteDetail.item;
          if (localItem != null) {
            final resolvedPerp =
                effectiveItem.perpetratorNames.trim().isNotEmpty
                    ? effectiveItem.perpetratorNames
                    : localItem.perpetratorNames;
            final resolvedVictim = effectiveItem.victimName.trim().isNotEmpty
                ? effectiveItem.victimName
                : localItem.victimName;
            final resolvedReporterName =
                effectiveItem.reporterName.trim().isNotEmpty
                    ? effectiveItem.reporterName
                    : localItem.reporterName;
            final resolvedReporterClass =
                effectiveItem.reporterClass.trim().isNotEmpty
                    ? effectiveItem.reporterClass
                    : localItem.reporterClass;
            final resolvedReporterPhone =
                effectiveItem.reporterPhone.trim().isNotEmpty
                    ? effectiveItem.reporterPhone
                    : localItem.reporterPhone;
            final resolvedReporterEmail =
                effectiveItem.reporterEmail.trim().isNotEmpty
                    ? effectiveItem.reporterEmail
                    : localItem.reporterEmail;
            final hydratedFiles = effectiveItem.evidenceFiles.map((remoteAtt) {
              EvidenceAttachment? localMatch;
              for (final candidate in localItem!.evidenceFiles) {
                final sameStorage = remoteAtt.storagePath != null &&
                    remoteAtt.storagePath!.isNotEmpty &&
                    candidate.storagePath == remoteAtt.storagePath;
                if (sameStorage || candidate.fileName == remoteAtt.fileName) {
                  localMatch = candidate;
                  break;
                }
              }
              if (localMatch == null) return remoteAtt;
              final keepBytes =
                  (remoteAtt.bytes == null || remoteAtt.bytes!.isEmpty)
                      ? localMatch.bytes
                      : remoteAtt.bytes;
              final keepLocalPath = (remoteAtt.localPath == null ||
                      remoteAtt.localPath!.isEmpty)
                  ? localMatch.localPath
                  : remoteAtt.localPath;
              return remoteAtt.copyWith(
                bytes: keepBytes,
                localPath: keepLocalPath,
                sizeBytes: remoteAtt.sizeBytes ?? localMatch.sizeBytes,
              );
            }).toList();
            effectiveItem = effectiveItem.copyWith(
              perpetratorNames: resolvedPerp,
              victimName: resolvedVictim,
              reporterName: resolvedReporterName,
              reporterClass: resolvedReporterClass,
              reporterPhone: resolvedReporterPhone,
              reporterEmail: resolvedReporterEmail,
              evidenceFiles: hydratedFiles.isNotEmpty
                  ? hydratedFiles
                  : (effectiveItem.evidenceFiles.isEmpty
                      ? localItem.evidenceFiles
                      : effectiveItem.evidenceFiles),
            );
          }
          final effectiveHistory =
              storedHistory.length > remoteDetail.history.length
                  ? storedHistory
                  : remoteDetail.history;
          return ReportDetailData(
            item: effectiveItem,
            schoolName: remoteDetail.schoolName,
            history: effectiveHistory,
            messages: remoteDetail.messages,
          );
        }
      } on Object {
        // Fallback below to local cache detail.
      }
    }

    final item = localItem ??
        AnonymousReportItem(
          code: code,
          types: const {BullyingType.verbal},
          occurredAt: DateTime.now(),
          location: '-',
          narrative: 'Detail laporan tidak ditemukan.',
          status: ReportStatus.diterima,
          createdAt: DateTime.now(),
        );

    final msgKey = _messagesKeyFor(userScope, code);
    final cachedMsgs = _prefs.getJsonList(msgKey);
    final messages = cachedMsgs.map(ReportChatMessage.fromJson).toList();
    final history =
        storedHistory.isNotEmpty ? storedHistory : _buildFallbackHistory(item);

    return ReportDetailData(
      item: item,
      schoolName: 'SMAN 1 Nusantara',
      history: history,
      messages: messages,
    );
  }

  @override
  Future<Result<ReportChatMessage>> sendReportMessage({
    required String code,
    required String content,
    required String senderLabel,
    bool asCounselor = false,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const Err(ValidationFailure('Pesan tidak boleh kosong.'));
    }

    if (_remote.isRemoteEnabled &&
        _remote.hasAuthenticatedSession &&
        await _connectivity.isConnected) {
      try {
        final msg = await _remote.sendMessage(code: code, content: trimmed);
        return Ok(msg);
      } on Object {
        // Fallback below so UI keeps smooth offline behavior.
      }
    }

    final userScope = _resolveUserScope();
    final detail = await getReportDetail(code);
    final msg = ReportChatMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      senderRole: asCounselor ? 'guru_bk' : 'siswa',
      senderLabel: senderLabel,
      content: trimmed,
      createdAt: DateTime.now(),
    );
    final next = [...detail.messages, msg];
    await _prefs.setJsonList(
      _messagesKeyFor(userScope, code),
      next.map((e) => e.toJson()).toList(),
    );
    return Ok(msg);
  }

  @override
  Future<Result<List<AnonymousReportItem>>> advanceReportStatus(
    String code, {
    ReportStatus? nextStatus,
    String? note,
  }) async {
    final userScope = _resolveUserScope();
    final schoolList = await _loadLocalReports(
      userScope: userScope,
      isSchool: true,
    );
    final myList = await _loadLocalReports(userScope: userScope);

    final schoolIdx = schoolList.indexWhere((e) => e.code == code);
    final myIdx = myList.indexWhere((e) => e.code == code);
    final currentStatus = schoolIdx >= 0
        ? schoolList[schoolIdx].status
        : (myIdx >= 0 ? myList[myIdx].status : ReportStatus.diterima);
    final resolvedNext = nextStatus ??
        switch (currentStatus) {
          ReportStatus.diterima => ReportStatus.ditinjau,
          ReportStatus.ditinjau => ReportStatus.tindakLanjut,
          ReportStatus.tindakLanjut => ReportStatus.selesai,
          ReportStatus.selesai => ReportStatus.selesai,
        };

    final cleanNote = (note != null && note.trim().isNotEmpty)
        ? note.trim()
        : defaultDescForStatus(resolvedNext);

    final historyKey = _historyKeyFor(userScope, code);
    final stored = _prefs
        .getJsonList(historyKey)
        .map(ReportTimelineEntry.fromJson)
        .toList();

    if (schoolIdx >= 0) {
      if (stored.isEmpty) {
        await _appendLocalHistoryEntry(
          code,
          ReportTimelineEntry(
            status: ReportStatus.diterima,
            title: defaultTitleForStatus(ReportStatus.diterima),
            description: defaultDescForStatus(ReportStatus.diterima),
            changedAt: schoolList[schoolIdx].createdAt,
          ),
          userScope: userScope,
        );
      }
      schoolList[schoolIdx] =
          schoolList[schoolIdx].copyWith(status: resolvedNext);
      await _saveLocalReports(schoolList, userScope: userScope, isSchool: true);
    }

    if (myIdx >= 0) {
      if (stored.isEmpty && schoolIdx < 0) {
        await _appendLocalHistoryEntry(
          code,
          ReportTimelineEntry(
            status: ReportStatus.diterima,
            title: defaultTitleForStatus(ReportStatus.diterima),
            description: defaultDescForStatus(ReportStatus.diterima),
            changedAt: myList[myIdx].createdAt,
          ),
          userScope: userScope,
        );
      }
      myList[myIdx] = myList[myIdx].copyWith(status: resolvedNext);
      await _saveLocalReports(myList, userScope: userScope);
    }

    await _appendLocalHistoryEntry(
      code,
      ReportTimelineEntry(
        status: resolvedNext,
        title: defaultTitleForStatus(resolvedNext),
        description: cleanNote,
        changedAt: DateTime.now(),
      ),
      userScope: userScope,
    );

    if (_remote.isRemoteEnabled &&
        _remote.hasAuthenticatedSession &&
        await _connectivity.isConnected) {
      try {
        await _remote.advanceStatus(
          code: code,
          nextStatus: resolvedNext.wireValue,
          note: cleanNote,
        );
        final updated = await getSchoolReports();
        if (updated.isNotEmpty) return Ok(updated);
      } on Object {
        // Fallback cleanly to local update.
      }
    }

    final resultList = schoolIdx >= 0 ? schoolList : myList;
    return Ok(List<AnonymousReportItem>.unmodifiable(resultList));
  }
}
