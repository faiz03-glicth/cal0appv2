import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class DebugView extends StatefulWidget {
  const DebugView({super.key});

  @override
  State<DebugView> createState() => _DebugViewState();
}

class _DebugViewState extends State<DebugView> {
  @override
  Widget build(BuildContext context) {
    final logs = LogService.getLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text("System Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              setState(() {
                LogService.clear();
              });
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text("No logs recorded yet."))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final logEntry = logs[index];

                return ListTile(
                  dense: true, // Makes it compact like a log console
                  title: SelectableText(
                    // Allows highlighting specific words
                    logEntry,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color.fromARGB(255, 220, 220, 220),
                    ),
                  ),
                  onLongPress: () {
                    // Logic to copy the whole line to clipboard
                    Clipboard.setData(ClipboardData(text: logEntry));

                    // Visual feedback is key for UX!
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Copied to clipboard"),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
