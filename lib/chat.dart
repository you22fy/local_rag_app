class ChatModel {
  final int id;
  final String message;
  final bool isUser;
  final DateTime createdAt;
  final int sessionId;

  ChatModel({
    required this.id,
    required this.message,
    required this.isUser,
    required this.createdAt,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    // sqflite は num/String/Uint8List を推奨するため、bool を 0/1 に変換して保存する
    'isUser': isUser ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'sessionId': sessionId,
  };

  factory ChatModel.fromJson(Map<String, dynamic> json) => ChatModel(
    id: json['id'],
    message: json['message'],
    isUser: json['isUser'] == 1 || json['isUser'] == true,
    createdAt: DateTime.parse(json['createdAt']),
    sessionId: json['sessionId'] ?? 0,
  );
}

class ChatSessionModel {
  final int id;
  final DateTime createdAt;
  final String? firstMessageSnippet;

  ChatSessionModel({
    required this.id,
    required this.createdAt,
    this.firstMessageSnippet,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'firstMessageSnippet': firstMessageSnippet,
  };

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) =>
      ChatSessionModel(
        id: json['id'],
        createdAt: DateTime.parse(json['createdAt']),
        firstMessageSnippet: json['firstMessageSnippet'],
      );
}
