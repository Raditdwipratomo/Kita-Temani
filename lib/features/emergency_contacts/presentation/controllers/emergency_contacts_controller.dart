import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/sms_sender.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/emergency_contacts/data/repositories/emergency_contact_repository_impl.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/emergency_contacts/domain/repositories/emergency_contact_repository.dart';

final emergencyContactRepositoryProvider = Provider<EmergencyContactRepository>(
  (ref) => FullstackEmergencyContactRepository(
    client: ref.watch(supabaseClientProvider),
    prefs: ref.watch(localPreferencesServiceProvider),
  ),
);

class EmergencyContactsController extends Notifier<List<EmergencyContact>> {
  @override
  List<EmergencyContact> build() {
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final loaded = await ref.read(emergencyContactRepositoryProvider).getAll();
    state = loaded;
  }

  EmergencyContact? get primaryContact {
    for (final c in state) {
      if (c.isPrimary && c.isActive) return c;
    }
    for (final c in state) {
      if (c.isPrimary) return c;
    }
    for (final c in state) {
      if (c.isActive) return c;
    }
    return state.isNotEmpty ? state.first : null;
  }

  Future<Result<void>> toggleActive(String id, bool isActive) async {
    final repo = ref.read(emergencyContactRepositoryProvider);
    final res = await repo.toggleActive(id, isActive);
    if (res case Ok(:final value)) {
      state = value;
      return const Ok(null);
    } else if (res case Err(:final failure)) {
      return Err(failure);
    }
    return const Ok(null);
  }

  Future<Result<void>> setPrimary(String id) async {
    final repo = ref.read(emergencyContactRepositoryProvider);
    final res = await repo.setPrimary(id);
    if (res case Ok(:final value)) {
      state = value;
      return const Ok(null);
    } else if (res case Err(:final failure)) {
      return Err(failure);
    }
    return const Ok(null);
  }

  Future<Result<void>> saveContact(EmergencyContact contact) async {
    final repo = ref.read(emergencyContactRepositoryProvider);
    final res = await repo.saveContact(contact);
    if (res case Ok(:final value)) {
      state = value;
      return const Ok(null);
    } else if (res case Err(:final failure)) {
      return Err(failure);
    }
    return const Ok(null);
  }

  Future<Result<void>> deleteContact(String id) async {
    final repo = ref.read(emergencyContactRepositoryProvider);
    final res = await repo.deleteContact(id);
    if (res case Ok(:final value)) {
      state = value;
      return const Ok(null);
    } else if (res case Err(:final failure)) {
      return Err(failure);
    }
    return const Ok(null);
  }

  Future<bool> sendTestSms() async {
    final primary = primaryContact;
    if (primary == null) return false;
    final student = ref.read(studentProfileProvider);
    final ok = await ref.read(smsSenderProvider).sendToSingle(
          primary.phone,
          'KitaTemani: Ini SMS tes kesiapan darurat dari ${student.name} (${student.className}).',
        );
    if (ok) {
      await ref.read(studentProfileProvider.notifier).markSmsTested();
    }
    return ok;
  }
}

final emergencyContactsControllerProvider =
    NotifierProvider<EmergencyContactsController, List<EmergencyContact>>(
  EmergencyContactsController.new,
);
