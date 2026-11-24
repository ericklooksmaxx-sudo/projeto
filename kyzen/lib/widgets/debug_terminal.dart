import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

class DebugTerminal {
  static final DebugTerminal _instance = DebugTerminal._internal();
  factory DebugTerminal() => _instance;
  DebugTerminal._internal();

  final List<String> _logs = [];
  final ValueNotifier<int> versionNotifier = ValueNotifier(0);

  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.add('[$timestamp] $message');
    if (_logs.length > 1000) {
      _logs.removeAt(0);
    }
    versionNotifier.value++;
  }

  void clearLogs() {
    _logs.clear();
    versionNotifier.value++;
  }

  List<String> get logs => _logs;
}

class DebugTerminalView extends StatefulWidget {
  const DebugTerminalView({super.key});

  @override
  State<DebugTerminalView> createState() => _DebugTerminalViewState();
}

class _DebugTerminalViewState extends State<DebugTerminalView> {
  final ScrollController _scrollController = ScrollController();
  final DebugTerminal _terminal = DebugTerminal();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Auto-scroll to bottom when new logs arrive
    _terminal.versionNotifier.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _terminal.versionNotifier.removeListener(_scrollToBottom);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _terminal.logs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _saveLogs() async {
    if (_terminal.logs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.noLogs)));
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final outputFolder = await SettingsService.instance.getDownloadPath();
      final timestamp = DateTime.now()
          .toString()
          .replaceAll(':', '-')
          .replaceAll(' ', '_')
          .split('.')[0];
      final fileName = 'log_$timestamp.txt';
      final logContent = _terminal.logs.join('\n');

      String savedPath;

      if (outputFolder.startsWith('content://')) {
        // Use SAF for content URIs
        const platform = MethodChannel('xyz.kyzendlc.app/storage');
        final fileUri = await platform.invokeMethod<String>('writeFile', {
          'uri': outputFolder,
          'fileName': fileName,
          'content': logContent,
        });

        if (fileUri != null) {
          savedPath = fileName;
        } else {
          throw Exception('Failed to write file to storage');
        }
      } else {
        // Regular file path
        final filePath = '$outputFolder/$fileName';
        final file = File(filePath);
        await file.writeAsString(logContent);
        savedPath = filePath;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logsSaved(savedPath))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorSavingLog(e.toString()))),
        );
      }
      debugPrint('Error saving log: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.debugTerminal),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveLogs,
            tooltip: context.l10n.saveLogs,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _terminal.clearLogs,
            tooltip: context.l10n.clearLogs,
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: ValueListenableBuilder<int>(
          valueListenable: _terminal.versionNotifier,
          builder: (context, _, child) {
            final logs = _terminal.logs;
            if (logs.isEmpty) {
              return Center(
                child: Text(
                  context.l10n.noLogs,
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                  ),
                ),
              );
            }

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.0),
                  child: SelectableText(
                    logs[index],
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

void setupDebugPrint() {
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    originalDebugPrint.call(message, wrapWidth: wrapWidth);
    if (message != null) {
      DebugTerminal().addLog(message);
    }
  };
}
