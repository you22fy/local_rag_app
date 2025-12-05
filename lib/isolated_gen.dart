// ignore_for_file: avoid_print

import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String> getModelPath() async {
  // アプリのドキュメントディレクトリを取得
  final directory = await getApplicationDocumentsDirectory();
  final modelPath = '${directory.path}/gemma-3-270M-BF16.gguf';

  // ファイルが存在しなければアセットからコピー
  if (!await File(modelPath).exists()) {
    final byteData = await rootBundle.load(
      'assets/models/gemma-3-270M-BF16.gguf',
    );
    final file = File(modelPath);
    await file.writeAsBytes(byteData.buffer.asUint8List());
  }

  return modelPath;
}

Future<void> generateTestReply(String prompt) async {
  print("generateTestReply: $prompt");
  ContextParams contextParams = ContextParams();
  contextParams.nPredict = -1;
  contextParams.nCtx = 8192;

  print("contextParams: $contextParams");

  final samplerParams = SamplerParams();
  samplerParams.temp = 0.7;
  samplerParams.topK = 64;
  samplerParams.topP = 0.95;
  samplerParams.penaltyRepeat = 1.1;

  print("samplerParams: $samplerParams");
  String modelPath = await getModelPath();
  final loadCommand = LlamaLoad(
    path: modelPath,
    modelParams: ModelParams(),
    contextParams: contextParams,
    samplingParams: samplerParams,
  );

  print("loadCommand: $loadCommand");
  final llamaParent = LlamaParent(loadCommand);

  try {
    print("Initializing Llama...");
    await llamaParent.init();

    int i = 0;
    List<String> prompts = [
      getPrompt("What is 2 * 4?"),
      getPrompt("What is 4 * 4?"),
      getPrompt("hey what is your name?"),
    ];

    llamaParent.stream.listen(
      (response) => print("Response: $response"),
      onError: (e) => stderr.writeln("Stream error: $e"),
    );

    llamaParent.completions.listen((event) {
      if (!event.success) {
        stderr.writeln("Completion error: ${event.errorDetails}");
        return;
      }

      i++;
      if (i >= prompts.length) {
        llamaParent.dispose();
      } else {
        print("\n----- Next prompt -----\n");
        llamaParent.sendPrompt(prompts[i]);
      }
    }, onError: (e) => stderr.writeln("Completion error: $e"));

    llamaParent.sendPrompt(prompts[0]);
  } catch (e) {
    stderr.writeln("Error: $e");
    await llamaParent.dispose();
    print("Error: $e");
    exit(1);
  }
}

String getPrompt(String content) {
  ChatHistory history = ChatHistory()
    ..addMessage(role: Role.user, content: content)
    ..addMessage(role: Role.assistant, content: "");
  return history.exportFormat(ChatFormat.gemini, leaveLastAssistantOpen: true);
}
