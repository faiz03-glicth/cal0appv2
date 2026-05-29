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
    final allLogsText = logs.join('\n');

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('System Logs', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Copy all button
          IconButton(
            icon: const Icon(Icons.copy_all, color: Colors.white),
            tooltip: 'Copy all logs',
            onPressed: logs.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: allLogsText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All logs copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
          ),
          // Clear button
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            tooltip: 'Clear logs',
            onPressed: () => setState(() => LogService.clear()),
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text(
                'No logs recorded yet.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : Column(
              children: [
                // Info bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFF2D2D2D),
                  child: Text(
                    '${logs.length} entries — hold to select, or use Copy All',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
                // Selectable log block
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      allLogsText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFFDCDCDC),
                        height: 1.6,
                      ),
                      // Allows selecting all with long press then drag
                      contextMenuBuilder: (context, editableTextState) {
                        return AdaptiveTextSelectionToolbar.editableText(
                          editableTextState: editableTextState,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
