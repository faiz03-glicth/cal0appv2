import 'package:flutter/material.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class DebugView extends StatelessWidget {
  const DebugView({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = LogService.getLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text("System Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => LogService.clear(),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          return Text(
            logs[index],
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          );
        },
      ),
    );
  }
}
