import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';

abstract interface class EmergencyContactRepository {
  Future<List<EmergencyContact>> getAll();
  Future<List<EmergencyContact>> activeContacts();
  Future<EmergencyContact?> primaryContact();
  Future<Result<List<EmergencyContact>>> saveContact(EmergencyContact contact);
  Future<Result<List<EmergencyContact>>> toggleActive(String id, bool isActive);
  Future<Result<List<EmergencyContact>>> setPrimary(String id);
  Future<Result<List<EmergencyContact>>> deleteContact(String id);
}
