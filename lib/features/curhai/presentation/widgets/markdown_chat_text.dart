import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';

typedef MarkdownStyleResolver = TextStyle Function(TextStyle style);

/// Lightweight zero-dependency Markdown renderer tailored for CurhAI chat
/// bubbles. Supports bold (`**...**`, `__...__`), italic (`*...*`, `_..._`),
/// bold+italic (`***...***`), strikethrough (`~~...~~`), inline code
/// (`` `...` ``), links (`[label](url)`), headings (`#`), blockquotes (`>`),
/// horizontal rules (`---`), bullet lists (`- `, `* `, `• `), and numbered
/// lists (`1. `) with hanging indents.
class MarkdownChatText extends StatelessWidget {
  const MarkdownChatText({
    required this.data,
    required this.style,
    super.key,
    this.resolveStyle,
    this.codeStyle,
    this.codeBackgroundColor,
    this.accentColor,
  });

  final String data;
  final TextStyle style;

  /// Optional style resolver (e.g. wrapping derived styles with
  /// `GoogleFonts.inter(...)`) so bold/italic weights load their real web and
  /// mobile font variants rather than inheriting a regular-only font family.
  final MarkdownStyleResolver? resolveStyle;

  final TextStyle? codeStyle;
  final Color? codeBackgroundColor;
  final Color? accentColor;

  TextStyle _resolve(TextStyle candidate) =>
      resolveStyle != null ? resolveStyle!(candidate) : candidate;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseMarkdownBlocks(data);
    if (blocks.isEmpty) {
      return Text(data, style: style);
    }

    final effectiveAccent = accentColor ?? AppColors.biruTinta;
    final effectiveCodeBg = codeBackgroundColor ?? AppColors.tintIndigo;

    if (blocks.length == 1 && blocks.first is _ParagraphBlock) {
      final para = blocks.first as _ParagraphBlock;
      return Text.rich(
        TextSpan(
          style: style,
          children: parseMarkdownInlineSpans(
            para.text,
            style,
            resolveStyle: resolveStyle,
            codeStyle: codeStyle,
            codeBackgroundColor: effectiveCodeBg,
            linkColor: effectiveAccent,
          ),
        ),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (i > 0) {
        final prev = blocks[i - 1];
        final bothList = prev is _ListItemBlock && block is _ListItemBlock;
        children.add(SizedBox(height: bothList ? 5 : 8));
      }
      children.add(
        _buildBlockWidget(
          block: block,
          baseStyle: style,
          accentColor: effectiveAccent,
          codeBg: effectiveCodeBg,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildBlockWidget({
    required _MarkdownBlock block,
    required TextStyle baseStyle,
    required Color accentColor,
    required Color codeBg,
  }) {
    switch (block) {
      case _ParagraphBlock(:final text):
        return Text.rich(
          TextSpan(
            style: baseStyle,
            children: parseMarkdownInlineSpans(
              text,
              baseStyle,
              resolveStyle: resolveStyle,
              codeStyle: codeStyle,
              codeBackgroundColor: codeBg,
              linkColor: accentColor,
            ),
          ),
        );

      case _HeadingBlock(:final level, :final text):
        final baseSize = baseStyle.fontSize ?? 13.5;
        final headingSize = level <= 2 ? baseSize + 2.0 : baseSize + 1.0;
        final headingStyle = _resolve(
          baseStyle.copyWith(
            fontSize: headingSize,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        );
        return Text.rich(
          TextSpan(
            style: headingStyle,
            children: parseMarkdownInlineSpans(
              text,
              headingStyle,
              resolveStyle: resolveStyle,
              codeStyle: codeStyle,
              codeBackgroundColor: codeBg,
              linkColor: accentColor,
            ),
          ),
        );

      case _ListItemBlock(:final marker, :final indentLevel, :final text):
        final leftIndent = indentLevel.clamp(0, 3) * 14.0;
        final markerStyle = _resolve(
          baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: baseStyle.color,
          ),
        );
        return Padding(
          padding: EdgeInsets.only(left: leftIndent),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(marker, style: markerStyle),
              ),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: baseStyle,
                    children: parseMarkdownInlineSpans(
                      text,
                      baseStyle,
                      resolveStyle: resolveStyle,
                      codeStyle: codeStyle,
                      codeBackgroundColor: codeBg,
                      linkColor: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockquoteBlock(:final text):
        final quoteStyle = _resolve(
          baseStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: AppColors.inkSlate,
          ),
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: accentColor.withValues(alpha: 0.55),
                width: 3,
              ),
            ),
          ),
          child: Text.rich(
            TextSpan(
              style: quoteStyle,
              children: parseMarkdownInlineSpans(
                text,
                quoteStyle,
                resolveStyle: resolveStyle,
                codeStyle: codeStyle,
                codeBackgroundColor: codeBg,
                linkColor: accentColor,
              ),
            ),
          ),
        );

      case _DividerBlock():
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderHairline,
          ),
        );
    }
  }
}

sealed class _MarkdownBlock {
  const _MarkdownBlock();
}

final class _ParagraphBlock extends _MarkdownBlock {
  const _ParagraphBlock(this.text);
  final String text;
}

final class _HeadingBlock extends _MarkdownBlock {
  const _HeadingBlock({required this.level, required this.text});
  final int level;
  final String text;
}

final class _ListItemBlock extends _MarkdownBlock {
  const _ListItemBlock({
    required this.marker,
    required this.indentLevel,
    required this.text,
  });
  final String marker;
  final int indentLevel;
  final String text;
}

final class _BlockquoteBlock extends _MarkdownBlock {
  const _BlockquoteBlock(this.text);
  final String text;
}

final class _DividerBlock extends _MarkdownBlock {
  const _DividerBlock();
}

final RegExp _headingRegex = RegExp(r'^(#{1,6})\s+(.+)$');
final RegExp _unorderedListRegex = RegExp(r'^([ \t]*)[-*•]\s+(.+)$');
final RegExp _orderedListRegex = RegExp(r'^([ \t]*)(\d+[.)])\s+(.+)$');
final RegExp _blockquoteRegex = RegExp(r'^>\s?(.*)$');
final RegExp _dividerRegex = RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$');

List<_MarkdownBlock> _parseMarkdownBlocks(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  final blocks = <_MarkdownBlock>[];
  final paragraphLines = <String>[];
  final quoteLines = <String>[];

  void flushParagraph() {
    if (paragraphLines.isEmpty) return;
    blocks.add(_ParagraphBlock(paragraphLines.join('\n')));
    paragraphLines.clear();
  }

  void flushQuote() {
    if (quoteLines.isEmpty) return;
    blocks.add(_BlockquoteBlock(quoteLines.join('\n')));
    quoteLines.clear();
  }

  for (final rawLine in lines) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      flushParagraph();
      flushQuote();
      continue;
    }

    if (_dividerRegex.hasMatch(trimmed)) {
      flushParagraph();
      flushQuote();
      blocks.add(const _DividerBlock());
      continue;
    }

    final headingMatch = _headingRegex.firstMatch(trimmed);
    if (headingMatch != null) {
      flushParagraph();
      flushQuote();
      blocks.add(
        _HeadingBlock(
          level: headingMatch.group(1)!.length,
          text: headingMatch.group(2)!.trim(),
        ),
      );
      continue;
    }

    final quoteMatch = _blockquoteRegex.firstMatch(trimmed);
    if (quoteMatch != null) {
      flushParagraph();
      quoteLines.add(quoteMatch.group(1)!.trimRight());
      continue;
    }

    final bulletMatch = _unorderedListRegex.firstMatch(rawLine);
    if (bulletMatch != null) {
      flushParagraph();
      flushQuote();
      final indent = _computeIndentLevel(bulletMatch.group(1)!);
      blocks.add(
        _ListItemBlock(
          marker: indent > 0 ? '◦' : '•',
          indentLevel: indent,
          text: bulletMatch.group(2)!.trim(),
        ),
      );
      continue;
    }

    final orderedMatch = _orderedListRegex.firstMatch(rawLine);
    if (orderedMatch != null) {
      flushParagraph();
      flushQuote();
      final indent = _computeIndentLevel(orderedMatch.group(1)!);
      blocks.add(
        _ListItemBlock(
          marker: orderedMatch.group(2)!,
          indentLevel: indent,
          text: orderedMatch.group(3)!.trim(),
        ),
      );
      continue;
    }

    flushQuote();
    paragraphLines.add(rawLine.trimRight());
  }

  flushParagraph();
  flushQuote();
  return blocks;
}

int _computeIndentLevel(String leadingWhitespace) {
  var spaces = 0;
  for (var i = 0; i < leadingWhitespace.length; i++) {
    spaces += leadingWhitespace[i] == '\t' ? 2 : 1;
  }
  return spaces ~/ 2;
}

/// Parses inline Markdown syntax (`**bold**`, `__bold__`, `*italic*`,
/// `_italic_`, `***bold italic***`, `~~strike~~`, `` `code` ``, and
/// `[label](url)`) into styled [InlineSpan] nodes without ever dropping text
/// when delimiters are unclosed.
List<InlineSpan> parseMarkdownInlineSpans(
  String input,
  TextStyle baseStyle, {
  MarkdownStyleResolver? resolveStyle,
  TextStyle? codeStyle,
  Color? codeBackgroundColor,
  Color? linkColor,
}) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  final effectiveCodeBg = codeBackgroundColor ?? AppColors.tintIndigo;
  final effectiveLinkColor = linkColor ?? AppColors.biruTinta;

  TextStyle resolve(TextStyle candidate) =>
      resolveStyle != null ? resolveStyle(candidate) : candidate;

  void flushBuffer() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(text: buffer.toString(), style: baseStyle));
    buffer.clear();
  }

  var i = 0;
  while (i < input.length) {
    final ch = input[i];

    // Escaped markdown punctuation (e.g. \* or \_)
    if (ch == r'\' && i + 1 < input.length && _isEscapable(input[i + 1])) {
      buffer.write(input[i + 1]);
      i += 2;
      continue;
    }

    // Inline code: `code`
    if (ch == '`') {
      final end = input.indexOf('`', i + 1);
      if (end > i + 1) {
        flushBuffer();
        final effectiveCodeStyle = codeStyle ??
            baseStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: ((baseStyle.fontSize ?? 13.5) - 0.5).clamp(10.0, 24.0),
              backgroundColor: effectiveCodeBg,
            );
        spans.add(
          TextSpan(
            text: input.substring(i + 1, end),
            style: effectiveCodeStyle,
          ),
        );
        i = end + 1;
        continue;
      }
    }

    // Bold + Italic: ***text*** or ___text___
    final isTripleStart = (ch == '*' || ch == '_') &&
        i + 2 < input.length &&
        input[i + 1] == ch &&
        input[i + 2] == ch;
    if (isTripleStart) {
      final canOpen =
          ch == '*' || i == 0 || !_isWordChar(input.codeUnitAt(i - 1));
      if (canOpen) {
        final end = _findClosingTriple(input, i + 3, ch);
        if (end > i + 3) {
          flushBuffer();
          final inner = input.substring(i + 3, end);
          final nextStyle = resolve(
            baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          );
          spans.addAll(
            parseMarkdownInlineSpans(
              inner,
              nextStyle,
              resolveStyle: resolveStyle,
              codeStyle: codeStyle,
              codeBackgroundColor: effectiveCodeBg,
              linkColor: effectiveLinkColor,
            ),
          );
          i = end + 3;
          continue;
        }
      }
    }

    // Bold: **text** or __text__ (skip when part of an unmatched triple run
    // like `***Penting** banget*` so single-italic handles outer wrapper)
    if (!isTripleStart &&
        (ch == '*' || ch == '_') &&
        i + 1 < input.length &&
        input[i + 1] == ch) {
      final canOpen =
          ch == '*' || i == 0 || !_isWordChar(input.codeUnitAt(i - 1));
      if (canOpen) {
        final end = _findClosingDouble(input, i + 2, ch);
        if (end > i + 2) {
          flushBuffer();
          final inner = input.substring(i + 2, end);
          final nextStyle = resolve(
            baseStyle.copyWith(fontWeight: FontWeight.w700),
          );
          spans.addAll(
            parseMarkdownInlineSpans(
              inner,
              nextStyle,
              resolveStyle: resolveStyle,
              codeStyle: codeStyle,
              codeBackgroundColor: effectiveCodeBg,
              linkColor: effectiveLinkColor,
            ),
          );
          i = end + 2;
          continue;
        }
      }
    }

    // Strikethrough: ~~text~~
    if (ch == '~' && i + 1 < input.length && input[i + 1] == '~') {
      final end = input.indexOf('~~', i + 2);
      if (end > i + 2 && input.substring(i + 2, end).trim().isNotEmpty) {
        flushBuffer();
        final inner = input.substring(i + 2, end);
        final nextStyle = resolve(
          baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        );
        spans.addAll(
          parseMarkdownInlineSpans(
            inner,
            nextStyle,
            resolveStyle: resolveStyle,
            codeStyle: codeStyle,
            codeBackgroundColor: effectiveCodeBg,
            linkColor: effectiveLinkColor,
          ),
        );
        i = end + 2;
        continue;
      }
    }

    // Italic: *text* or _text_ (also handles outer `*` of `***bold** italic*`)
    if ((ch == '*' || ch == '_') &&
        i + 1 < input.length &&
        input[i + 1] != ' ' &&
        (input[i + 1] != ch || isTripleStart)) {
      final canOpen =
          ch == '*' || i == 0 || !_isWordChar(input.codeUnitAt(i - 1));
      if (canOpen) {
        final end = _findClosingSingle(input, i + 1, ch);
        if (end > i + 1) {
          flushBuffer();
          final inner = input.substring(i + 1, end);
          final nextStyle = resolve(
            baseStyle.copyWith(fontStyle: FontStyle.italic),
          );
          spans.addAll(
            parseMarkdownInlineSpans(
              inner,
              nextStyle,
              resolveStyle: resolveStyle,
              codeStyle: codeStyle,
              codeBackgroundColor: effectiveCodeBg,
              linkColor: effectiveLinkColor,
            ),
          );
          i = end + 1;
          continue;
        }
      }
    }

    // Markdown link: [label](https://...)
    if (ch == '[') {
      final closeBracket = input.indexOf(']', i + 1);
      if (closeBracket > i + 1 &&
          closeBracket + 1 < input.length &&
          input[closeBracket + 1] == '(') {
        final closeParen = input.indexOf(')', closeBracket + 2);
        if (closeParen > closeBracket + 2) {
          final url = input.substring(closeBracket + 2, closeParen).trim();
          final isSupportedUrl = url.startsWith('https://') ||
              url.startsWith('http://') ||
              url.startsWith('mailto:') ||
              url.startsWith('tel:');
          if (isSupportedUrl) {
            flushBuffer();
            final label = input.substring(i + 1, closeBracket);
            final linkStyle = resolve(
              baseStyle.copyWith(
                color: effectiveLinkColor,
                decoration: TextDecoration.underline,
                decorationColor: effectiveLinkColor,
                fontWeight: FontWeight.w600,
              ),
            );
            spans.addAll(
              parseMarkdownInlineSpans(
                label,
                linkStyle,
                resolveStyle: resolveStyle,
                codeStyle: codeStyle,
                codeBackgroundColor: effectiveCodeBg,
                linkColor: effectiveLinkColor,
              ),
            );
            i = closeParen + 1;
            continue;
          }
        }
      }
    }

    buffer.write(ch);
    i++;
  }

  flushBuffer();
  return spans;
}

bool _isEscapable(String ch) =>
    ch == '*' ||
    ch == '_' ||
    ch == '`' ||
    ch == '~' ||
    ch == '[' ||
    ch == ']' ||
    ch == r'\';

bool _isWordChar(int codeUnit) {
  final isUpper = codeUnit >= 0x41 && codeUnit <= 0x5A;
  final isLower = codeUnit >= 0x61 && codeUnit <= 0x7A;
  final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
  final isUnderscore = codeUnit == 0x5F;
  return isUpper || isLower || isDigit || isUnderscore;
}

int _findClosingTriple(String input, int start, String marker) {
  final triple = '$marker$marker$marker';
  var idx = start;
  while (idx < input.length) {
    final pos = input.indexOf(triple, idx);
    if (pos == -1) return -1;
    final inner = input.substring(start, pos);
    final validBoundary = marker == '*' ||
        pos + 3 == input.length ||
        !_isWordChar(input.codeUnitAt(pos + 3));
    if (inner.trim().isNotEmpty && validBoundary) {
      return pos;
    }
    idx = pos + 3;
  }
  return -1;
}

int _findClosingDouble(String input, int start, String marker) {
  var j = start;
  var singleMarkerCount = 0;
  while (j + 1 < input.length) {
    if (input[j] == r'\') {
      j += 2;
      continue;
    }
    if (input[j] == marker && input[j + 1] == marker) {
      var runLen = 2;
      while (j + runLen < input.length && input[j + runLen] == marker) {
        runLen++;
      }
      final closePos = (runLen == 3 && singleMarkerCount.isOdd) ? j + 1 : j;
      final inner = input.substring(start, closePos);
      final validBoundary = marker == '*' ||
          closePos + 2 == input.length ||
          !_isWordChar(input.codeUnitAt(closePos + 2));
      if (inner.trim().isNotEmpty && validBoundary) {
        return closePos;
      }
      j += runLen;
      continue;
    }
    if (input[j] == marker) {
      singleMarkerCount++;
    }
    j++;
  }
  return -1;
}

int _findClosingSingle(String input, int start, String marker) {
  var j = start;
  var doubleMarkerCount = 0;
  while (j < input.length) {
    if (input[j] == r'\') {
      j += 2;
      continue;
    }
    if (input[j] == marker) {
      var runLen = 1;
      while (j + runLen < input.length && input[j + runLen] == marker) {
        runLen++;
      }
      if (runLen == 1) {
        final prevChar = input[j - 1];
        final validBoundary = marker == '*' ||
            j + 1 == input.length ||
            !_isWordChar(input.codeUnitAt(j + 1));
        if (prevChar != ' ' && validBoundary) {
          return j;
        }
      } else if (runLen == 3 && doubleMarkerCount.isOdd) {
        final closePos = j + 2;
        final validBoundary = marker == '*' ||
            closePos + 1 == input.length ||
            !_isWordChar(input.codeUnitAt(closePos + 1));
        if (validBoundary) {
          return closePos;
        }
      } else if (runLen == 2) {
        doubleMarkerCount++;
      }
      j += runLen;
      continue;
    }
    j++;
  }
  return -1;
}
