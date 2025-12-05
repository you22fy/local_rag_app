import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:app/isolated_gen.dart';
import 'package:flutter/services.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/src/llama_cpp.dart';

class LlmClient {
  /// アセットからローカルファイルへコピーするヘルパー関数
  /// モデルファイル(.gguf)などをドキュメントフォルダに配置するために使用します
  Future<String> _copyAssetToLocal(String assetPath, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$filename';
    final file = File(filePath);

    // すでにファイルが存在する場合はコピーをスキップします
    // ※モデルを更新した場合は、一度アプリを削除するか、ここを調整して上書きしてください
    if (await file.exists()) {
      return filePath;
    }

    print('Copying $filename from assets to local storage...');
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
      print('Copy completed: $filePath');
    } catch (e) {
      print('Error copying asset $assetPath: $e');
      rethrow;
    }

    return filePath;
  }

  Future<String> generateReply(String userMessage) async {
    await generateTestReply(userMessage);
    return "";
    print('generateReply: $userMessage');

    // ---------------------------------------------------------
    // 1. ライブラリ (.dylib) のパス設定
    // ---------------------------------------------------------
    // Llama.libraryPath = "libllama.dylib";
    final lib = llama_cpp(DynamicLibrary.open("libllama.dylib"));
    lib.llama_backend_init();

    // ---------------------------------------------------------
    // 2. モデル (.gguf) の準備
    // ---------------------------------------------------------
    // モデルファイルはXcodeに埋め込むと巨大になりすぎるため、
    // assetsからアプリ起動時にドキュメントフォルダへコピーして使います。
    final modelPath = await _copyAssetToLocal(
      "assets/models/gemma-3-270M-BF16.gguf",
      "gemma-3-270M-BF16.gguf",
    );
    print('Model path ready: $modelPath');

    // ---------------------------------------------------------
    // 3. Llamaの初期化と実行
    // ---------------------------------------------------------
    final loadCommand = LlamaLoad(
      path: modelPath,
      modelParams: ModelParams(),
      contextParams: ContextParams(),
      samplingParams: SamplerParams(),
      format: ChatMLFormat(),
    );

    final llamaParent = LlamaParent(loadCommand);

    try {
      print('Initializing Llama...');
      await llamaParent.init();
      print('Initialization successful.');
    } catch (e) {
      print("Init error: $e");
      // ここでエラーが出る場合は、ライブラリのパス間違いやアーキテクチャ不一致の可能性があります
      rethrow;
    }

    var fullResponse = '';
    final completer = Completer<String>();

    llamaParent.stream.listen(
      (response) {
        // 生成されたトークンを順次結合
        fullResponse += response;
        // 必要に応じてここで途中経過をUIに通知できます
      },
      onError: (error) {
        print("Stream error: $error");
        if (!completer.isCompleted) completer.completeError(error);
      },
      onDone: () {
        print('Stream done');
        if (!completer.isCompleted) completer.complete(fullResponse);

        // メモリリーク防止のため、使い終わったらdisposeするのが理想的ですが、
        // llama_cpp_dartの仕様に合わせて管理してください。
        // llamaParent.dispose(); // ライブラリにdisposeがある場合
      },
    );

    // プロンプト送信
    llamaParent.sendPrompt(userMessage);

    // 生成完了まで待機して結果を返す
    return completer.future;
  }
}
