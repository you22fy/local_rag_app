import 'package:app/chat.dart';
import 'package:app/db.dart';
import 'package:app/llm_client.dart';
import 'package:app/session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final currentSessionProvider = NotifierProvider<CurrentSessionNotifier, int?>(
  () => CurrentSessionNotifier(),
);

class CurrentSessionNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setSession(int? sessionId) {
    state = sessionId;
  }
}

final chatListProvider = AsyncNotifierProvider<ChatNotifier, List<ChatModel>>(
  () => ChatNotifier(),
);

class ChatNotifier extends AsyncNotifier<List<ChatModel>> {
  final _llmClient = LlmClient();

  @override
  Future<List<ChatModel>> build() async {
    await ref.read(databaseProvider.future);

    final sessionId = ref.read(currentSessionProvider);
    final dbNotifier = ref.read(databaseProvider.notifier);

    if (sessionId == null) {
      final latestSession = await dbNotifier.getLatestSession();
      if (latestSession != null) {
        ref.read(currentSessionProvider.notifier).setSession(latestSession.id);
        return await dbNotifier.fetchChats(sessionId: latestSession.id);
      }
      return [];
    }
    return await dbNotifier.fetchChats(sessionId: sessionId);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    await ref.read(databaseProvider.future);

    final sessionId = ref.read(currentSessionProvider);
    final dbNotifier = ref.read(databaseProvider.notifier);

    int activeSessionId;
    if (sessionId == null) {
      activeSessionId = await dbNotifier.createSession(
        firstMessageSnippet: text.length > 30 ? text.substring(0, 30) : text,
      );
      ref.read(currentSessionProvider.notifier).setSession(activeSessionId);
      ref.invalidate(sessionListProvider);
    } else {
      activeSessionId = sessionId;
    }

    final userChat = ChatModel(
      id: 0, // 一時的なID、DBから取得したIDで更新される
      message: text,
      isUser: true,
      createdAt: DateTime.now(),
      sessionId: activeSessionId,
    );
    final userChatId = await dbNotifier.insertChat(userChat);
    final userChatWithId = ChatModel(
      id: userChatId,
      message: userChat.message,
      isUser: userChat.isUser,
      createdAt: userChat.createdAt,
      sessionId: userChat.sessionId,
    );

    final currentChats = state.value ?? [];
    state = AsyncData([...currentChats, userChatWithId]);

    try {
      final reply = await _llmClient.generateReply(text);
      final llmChat = ChatModel(
        id: 0, // 一時的なID、DBから取得したIDで更新される
        message: reply,
        isUser: false,
        createdAt: DateTime.now(),
        sessionId: activeSessionId,
      );
      final llmChatId = await dbNotifier.insertChat(llmChat);
      final llmChatWithId = ChatModel(
        id: llmChatId,
        message: llmChat.message,
        isUser: llmChat.isUser,
        createdAt: llmChat.createdAt,
        sessionId: llmChat.sessionId,
      );

      final currentChats = state.value ?? [];
      state = AsyncData([...currentChats, llmChatWithId]);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> resetSession() async {
    // 念のため DB 初期化完了を待つ
    await ref.read(databaseProvider.future);

    final dbNotifier = ref.read(databaseProvider.notifier);
    final newSessionId = await dbNotifier.createSession();
    ref.read(currentSessionProvider.notifier).setSession(newSessionId);

    ref.invalidate(sessionListProvider);

    state = const AsyncData([]);
  }

  Future<void> loadSession(int sessionId) async {
    ref.read(currentSessionProvider.notifier).setSession(sessionId);
    ref.invalidateSelf();
  }
}
