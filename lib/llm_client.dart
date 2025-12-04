class LlmClient {
  /// 固定テキストを返す疑似LLMクライアント
  Future<String> generateReply(String userMessage) async {
    // ダミーの遅延を追加してリアルな挙動をシミュレート
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 固定テキスト + ユーザー入力の一部を含む応答を返す
    return 'これは固定のLLM応答です。あなたが「$userMessage」と言いましたね。';
  }
}

