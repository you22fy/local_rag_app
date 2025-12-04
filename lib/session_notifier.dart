import 'package:app/chat.dart';
import 'package:app/db.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final sessionListProvider =
    AsyncNotifierProvider<SessionNotifier, List<ChatSessionModel>>(
  () => SessionNotifier(),
);

class SessionNotifier extends AsyncNotifier<List<ChatSessionModel>> {
  @override
  Future<List<ChatSessionModel>> build() async {
    final dbNotifier = ref.read(databaseProvider.notifier);
    return await dbNotifier.fetchSessions();
  }
}

