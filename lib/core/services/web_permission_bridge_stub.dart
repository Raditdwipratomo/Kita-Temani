import 'package:kitatemani/core/services/web_permission_state.dart';

Future<WebPermissionQueryState> queryWebPermission(String name) async {
  return WebPermissionQueryState.unsupported;
}

Future<WebPermissionQueryState> requestWebMediaPermission({
  required bool video,
  required bool audio,
}) async {
  return WebPermissionQueryState.unsupported;
}

Stream<void> watchWebPermissionChanges(List<String> names) {
  return const Stream<void>.empty();
}
