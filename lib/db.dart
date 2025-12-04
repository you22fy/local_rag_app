import 'package:app/chat.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final databaseProvider = AsyncNotifierProvider<DatabaseNotifier, Database>(
  () => DatabaseNotifier(),
);

class DatabaseNotifier extends AsyncNotifier<Database> {
  @override
  Future<Database> build() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    return openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute(
          "CREATE TABLE chat_sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, createdAt TEXT, firstMessageSnippet TEXT)",
        );
        await db.execute(
          "CREATE TABLE chats(id INTEGER PRIMARY KEY AUTOINCREMENT, message TEXT, isUser BOOLEAN, createdAt TEXT, sessionId INTEGER)",
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // セッションテーブルを作成
          await db.execute(
            "CREATE TABLE IF NOT EXISTS chat_sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, createdAt TEXT, firstMessageSnippet TEXT)",
          );
          // chatsテーブルにsessionIdカラムを追加
          try {
            await db.execute("ALTER TABLE chats ADD COLUMN sessionId INTEGER");
          } catch (e) {
            // カラムが既に存在する場合は無視
          }
          // 既存のチャットレコードにデフォルトセッションを紐づけ
          final defaultSessionId = await db.insert('chat_sessions', {
            'createdAt': DateTime.now().toIso8601String(),
            'firstMessageSnippet': 'デフォルトセッション',
          });
          await db.update('chats', {
            'sessionId': defaultSessionId,
          }, where: 'sessionId IS NULL');
        }
      },
      version: 2,
    );
  }

  Future<int> insertChat(ChatModel chat) async {
    final db = state.requireValue;
    final json = chat.toJson();
    json.remove('id'); // AUTOINCREMENTなのでidは除外
    return await db.insert('chats', json);
  }

  Future<List<ChatModel>> fetchChats({required int sessionId}) async {
    final db = state.requireValue;
    final List<Map<String, dynamic>> maps = await db.query(
      'chats',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'createdAt ASC',
    );
    // 取得結果のMapは読み取り専用の場合があるため、書き換えは行わず
    // そのままモデルに変換する
    return List.generate(maps.length, (i) {
      final map = maps[i];
      return ChatModel.fromJson(map);
    });
  }

  Future<int> createSession({String? firstMessageSnippet}) async {
    final db = state.requireValue;
    return await db.insert('chat_sessions', {
      'createdAt': DateTime.now().toIso8601String(),
      'firstMessageSnippet': firstMessageSnippet,
    });
  }

  Future<List<ChatSessionModel>> fetchSessions() async {
    final db = state.requireValue;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) {
      return ChatSessionModel.fromJson(maps[i]);
    });
  }

  Future<ChatSessionModel?> getLatestSession() async {
    final sessions = await fetchSessions();
    return sessions.isNotEmpty ? sessions.first : null;
  }
}
