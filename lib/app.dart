import 'package:app/chat_notifier.dart';
import 'package:app/chat_page.dart';
import 'package:app/chat_session_drawer.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('LLM Chat'),
          actions: [
            Consumer(
              builder: (context, ref, _) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '新しいセッションを開始',
                  onPressed: () {
                    ref.read(chatListProvider.notifier).resetSession();
                  },
                );
              },
            ),
          ],
        ),
        drawer: const ChatSessionDrawer(),
        body: const ChatPage(),
      ),
    );
  }
}
