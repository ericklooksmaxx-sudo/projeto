import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

// dark
const _darkBackground = Color(0xFF1f1f1f);
const _darkLineNumbers = Color(0xFF858585);
const _darkBracket = Color(0xFFFFD700); // gold – {}, []
const _darkKey = Color(0xFF9CDCFE); // light blue – keys
const _darkString = Color(0xFFCE9178); // orange-brown – string values
const _darkNumber = Color(0xFFB5CEA8); // green – numbers
const _darkBool = Color(0xFF569CD6); // blue – true / false
const _darkNull = Color(0xFF569CD6); // blue – null
const _darkColon = Color(0xFFD4D4D4); // default text
const _darkComma = Color(0xFFD4D4D4);

// light
const _lightBackground = Color(0xFFFFFFFF);
const _lightLineNumbers = Color(0xFF237893);
const _lightBracket = Color(0xFF0431FA); // Brackets blue tint
const _lightKey = Color(0xFF0451A5); // Deep blue
const _lightString = Color(0xFFA31515); // Dark Red
const _lightNumber = Color(0xFF098658); // Green
const _lightBool = Color(0xFF0000FF); // Bright Blue
const _lightNull = Color(0xFF0000FF); // Bright Blue
const _lightColon = Color(0xFF000000); // Black
const _lightComma = Color(0xFF000000);

class JsonViewPage extends StatelessWidget {
  final String? uuid;
  final String? title;
  final dynamic json;
  final String? rawJson;

  const JsonViewPage({
    super.key,
    this.uuid,
    this.title,
    required this.json,
    this.rawJson,
  });

  String get displayTitle => title ?? uuid ?? 'JSON Viewer';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? _darkBackground : _lightBackground,
      appBar: AppBar(
        title: Text(
          displayTitle,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: isDarkMode ? _darkColon : _lightColon,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isDarkMode
            ? const Color(0xFF252526)
            : const Color(0xFFF3F3F3),
        foregroundColor: isDarkMode ? _darkColon : _lightColon,
        actions: [
          IconButton(
            tooltip: 'Copy JSON',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              final raw =
                  rawJson ?? const JsonEncoder.withIndent('  ').convert(json);
              Clipboard.setData(ClipboardData(text: raw));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: JsonViewWidget(json: json, rawJson: rawJson),
    );
  }

  // Pre-compiled regex
  static final RegExp _bracketOnlyRegex = RegExp(r'^[{\[\]},]+$');
  static final RegExp _kvRegex = RegExp(r'^("(?:[^"\\]|\\.)*")(\s*:\s*)(.+)$');
  static final RegExp _numberRegex = RegExp(r'^-?\d+(\.\d+)?$');
  static final RegExp _singleBracketRegex = RegExp(r'^[{\[\]]$');

  static List<TextSpan> parseLineFast(String line, bool isDarkMode) {
    final spans = <TextSpan>[];
    final indent = line.length - line.trimLeft().length;
    if (indent > 0) {
      spans.add(TextSpan(text: line.substring(0, indent)));
    }
    final trimmed = line.trimLeft();

    // Bracket / brace lines: "{", "}", "[", "]", "{,", "},", etc.
    if (_bracketOnlyRegex.hasMatch(trimmed)) {
      spans.add(
        TextSpan(
          text: trimmed,
          style: TextStyle(color: isDarkMode ? _darkBracket : _lightBracket),
        ),
      );
      return spans;
    }

    // Key-value line: "key": value
    final kvMatch = _kvRegex.firstMatch(trimmed);
    if (kvMatch != null) {
      // Key
      spans.add(
        TextSpan(
          text: kvMatch.group(1),
          style: TextStyle(color: isDarkMode ? _darkKey : _lightKey),
        ),
      );
      // Colon
      spans.add(
        TextSpan(
          text: kvMatch.group(2),
          style: TextStyle(color: isDarkMode ? _darkColon : _lightColon),
        ),
      );
      // Value (may end with comma)
      _addValueSpanFast(spans, kvMatch.group(3)!, isDarkMode);
      return spans;
    }

    _addValueSpanFast(spans, trimmed, isDarkMode);
    return spans;
  }

  static void _addValueSpanFast(
    List<TextSpan> spans,
    String raw,
    bool isDarkMode,
  ) {
    final hasComma = raw.endsWith(',');
    final val = hasComma ? raw.substring(0, raw.length - 1).trim() : raw.trim();

    Color color;

    // Strings
    if (val.startsWith('"') && val.endsWith('"')) {
      color = isDarkMode ? _darkString : _lightString;
    }
    // Booleans & Null
    else if (val == 'true' || val == 'false') {
      color = isDarkMode ? _darkBool : _lightBool;
    } else if (val == 'null') {
      color = isDarkMode ? _darkNull : _lightNull;
    }
    // Numbers
    else if (_numberRegex.hasMatch(val)) {
      color = isDarkMode ? _darkNumber : _lightNumber;
    }
    // Structural Brackets
    else if (_singleBracketRegex.hasMatch(val)) {
      color = isDarkMode ? _darkBracket : _lightBracket;
    }
    // Fallback
    else {
      color = isDarkMode ? _darkColon : _lightColon;
    }

    spans.add(
      TextSpan(
        text: val,
        style: TextStyle(color: color),
      ),
    );

    if (hasComma) {
      spans.add(
        TextSpan(
          text: ',',
          style: TextStyle(color: isDarkMode ? _darkComma : _lightComma),
        ),
      );
    }
  }
}

class JsonViewWidget extends StatefulWidget {
  final dynamic json;
  final String? rawJson;
  final ScrollController? verticalController;
  final ScrollController? horizontalController;
  final bool highlightSyntax;
  final bool showLineNumbers;

  const JsonViewWidget({
    super.key,
    this.json,
    this.rawJson,
    this.verticalController,
    this.horizontalController,
    this.highlightSyntax = true,
    this.showLineNumbers = true,
  });

  @override
  State<JsonViewWidget> createState() => _JsonViewWidgetState();
}

class _JsonViewWidgetState extends State<JsonViewWidget> {
  late ScrollController _verticalController;
  late ScrollController _horizontalController;
  bool _ownsVertical = false;
  bool _ownsHorizontal = false;

  List<String> _lines = const [];
  List<TextSpan?> _lineSpansCache = const [];
  int _maxLineLength = 0;
  double _charWidth = 7.82;
  double _lineNumberWidth = 50.0;
  bool _isDarkMode = false;
  bool _initialized = false;
  TextStyle? _cachedTextStyle;

  @override
  void initState() {
    super.initState();
    if (widget.verticalController != null) {
      _verticalController = widget.verticalController!;
    } else {
      _verticalController = ScrollController();
      _ownsVertical = true;
    }
    if (widget.horizontalController != null) {
      _horizontalController = widget.horizontalController!;
    } else {
      _horizontalController = ScrollController();
      _ownsHorizontal = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_initialized || _isDarkMode != isDark) {
      _isDarkMode = isDark;
      _computeLines();
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(JsonViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.json != oldWidget.json ||
        widget.rawJson != oldWidget.rawJson ||
        widget.highlightSyntax != oldWidget.highlightSyntax ||
        widget.showLineNumbers != oldWidget.showLineNumbers) {
      _computeLines();
    }
  }

  void _computeLines() {
    String raw;
    if (widget.rawJson != null) {
      raw = widget.rawJson!;
    } else if (widget.json != null) {
      try {
        raw = const JsonEncoder.withIndent('  ').convert(widget.json);
      } catch (e) {
        raw = widget.json.toString();
      }
    } else {
      raw = '';
    }

    if (raw.isEmpty) {
      setState(() {
        _lines = const [];
        _lineSpansCache = const [];
        _maxLineLength = 0;
      });
      return;
    }

    final lines = raw.split('\n');
    int maxLen = 0;
    for (int i = 0; i < lines.length; i++) {
      final len = lines[i].length;
      if (len > maxLen) maxLen = len;
    }

    final textColor = _isDarkMode ? _darkColon : _lightColon;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.6,
      color: textColor,
    );

    final tp = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final charWidth = tp.width > 0 ? tp.width : 7.82;

    double lineNumberWidth = 0.0;
    if (widget.showLineNumbers) {
      final digits = lines.length.toString().length;
      lineNumberWidth = (digits * charWidth) + 24.0;
    }

    setState(() {
      _lines = lines;
      _lineSpansCache = List<TextSpan?>.filled(lines.length, null);
      _maxLineLength = maxLen;
      _charWidth = charWidth;
      _lineNumberWidth = lineNumberWidth;
      _cachedTextStyle = style;
    });
  }

  TextSpan _getLineSpan(int index, TextStyle baseStyle) {
    if (!widget.highlightSyntax) {
      return TextSpan(text: _lines[index], style: baseStyle);
    }
    var span = _lineSpansCache[index];
    if (span == null) {
      final spans = JsonViewPage.parseLineFast(_lines[index], _isDarkMode);
      span = TextSpan(children: spans, style: baseStyle);
      _lineSpansCache[index] = span;
    }
    return span;
  }

  @override
  void dispose() {
    if (_ownsVertical) _verticalController.dispose();
    if (_ownsHorizontal) _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return const Center(child: Text('Empty JSON'));
    }

    final lineNumberColor = _isDarkMode ? _darkLineNumbers : _lightLineNumbers;
    final style =
        _cachedTextStyle ??
        TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.6,
          color: _isDarkMode ? _darkColon : _lightColon,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;

        final totalLineWidth = widget.showLineNumbers
            ? _lineNumberWidth + 16.0 + (_maxLineLength * _charWidth) + 32.0
            : (_maxLineLength * _charWidth) + 32.0;
        final contentWidth = math.max(viewportWidth, totalLineWidth);

        Widget area = SelectionArea(
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  height: viewportHeight,
                  child: ListView.builder(
                    controller: _verticalController,
                    itemCount: _lines.length,
                    itemExtent: 22.0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        height: 22.0,
                        child: Row(
                          children: [
                            if (widget.showLineNumbers) ...[
                              SelectionContainer.disabled(
                                child: SizedBox(
                                  width: _lineNumberWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Text(
                                      '${index + 1}',
                                      style: style.copyWith(
                                        color: lineNumberColor,
                                      ),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ] else
                              const SizedBox(width: 16),
                            Expanded(
                              child: Text.rich(
                                _getLineSpan(index, style),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        final hasLocalizations =
            Localizations.of<MaterialLocalizations>(
              context,
              MaterialLocalizations,
            ) !=
            null;

        if (!hasLocalizations) {
          area = Localizations(
            locale: const Locale('en', 'US'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: area,
          );
        }

        return area;
      },
    );
  }
}
