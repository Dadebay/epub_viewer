import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:selectable/selectable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class SelectableTextWithCustomToolbar extends StatelessWidget {
  final String text;
  final TextDirection textDirection;
  final TextStyle style;
  final String bookId;
  final bool isFirstPage;
  final String? chapterTitle;
  final int? pageNumber;
  final int? totalPages;

  const SelectableTextWithCustomToolbar({
    super.key,
    required this.text,
    required this.textDirection,
    required this.style,
    required this.bookId,
    this.isFirstPage = false,
    this.chapterTitle,
    this.pageNumber,
    this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic colors based on theme
    final menuBackgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Custom button style for both iOS and Android - consistent menu
    final customButtonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      foregroundColor: WidgetStateProperty.all(textColor),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      minimumSize: WidgetStateProperty.all(const Size(0, 44)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Theme(
      data: theme.copyWith(
        // Dynamic card background for popup menu
        cardTheme: CardTheme(
          color: menuBackgroundColor,
          elevation: 8,
          shadowColor: isDark ? Colors.white12 : Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        // Custom button styles
        textButtonTheme: TextButtonThemeData(style: customButtonStyle),
        elevatedButtonTheme: ElevatedButtonThemeData(style: customButtonStyle),
        filledButtonTheme: FilledButtonThemeData(style: customButtonStyle),
        // Override default popup menu theme
        popupMenuTheme: PopupMenuThemeData(
          color: menuBackgroundColor,
          elevation: 8,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        // Ensure consistent text style
        textTheme: theme.textTheme.copyWith(
          bodyMedium: TextStyle(color: textColor, fontSize: 16),
        ),
      ),
      child: Selectable(
        selectWordOnLongPress: true,
        selectWordOnDoubleTap: true,
        selectionColor: isDark ? Colors.grey.shade700.withValues(alpha: 0.5) : Colors.grey.shade300.withValues(alpha: 0.5),
        popupMenuItems: [
          SelectableMenuItem(
            title: CosmosEpubLocalization.t('add_note'),
            isEnabled: (controller) => controller!.isTextSelected,
            handler: (controller) {
              final selectedText = controller!.getSelection()!.text!;
              _handleAddNote(context, selectedText);
              return true;
            },
          ),
          SelectableMenuItem(
            title: CosmosEpubLocalization.t('share'),
            isEnabled: (controller) => controller!.isTextSelected,
            handler: (controller) {
              final selectedText = controller!.getSelection()!.text!;
              _handleShare(context, selectedText);
              return true;
            },
          ),
          SelectableMenuItem(
            type: SelectableMenuItemType.copy,
            title: CosmosEpubLocalization.t('copy'),
          ),
        ],
        child: Directionality(
          textDirection: textDirection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFirstPage && chapterTitle != null) ...[
                SizedBox(height: 20.h),
                Text(
                  chapterTitle!,
                  textAlign: TextAlign.center,
                  style: style.copyWith(
                    fontSize: (style.fontSize ?? 10) + 2,
                    fontFamily: 'SFPro',
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 16.h),
                SizedBox(height: 30.h),
              ],

              // Main text with paragraph indentation
              _buildFormattedText(text, style),
            ],
          ),
        ),
      ),
    );
  }

  String _formatText(String rawText) {
    if (rawText.isEmpty) return rawText;

    String formatted = rawText;

    // Remove all excessive whitespace (tabs, multiple spaces, non-breaking spaces, etc.)
    formatted = formatted.replaceAll('\u00A0', ' '); // Non-breaking space
    formatted = formatted.replaceAll('\u200B', ''); // Zero-width space
    formatted = formatted.replaceAll('\u2009', ' '); // Thin space
    formatted = formatted.replaceAll('\u202F', ' '); // Narrow no-break space
    formatted = formatted.replaceAll(RegExp(r'[ \t\u00A0\u200B\u2009\u202F]+'), ' ');

    // Remove spaces at the beginning and end of lines
    formatted = formatted.replaceAll(RegExp(r'^\s+', multiLine: true), '');
    formatted = formatted.replaceAll(RegExp(r'\s+$', multiLine: true), '');

    // Normalize line breaks (3+ newlines become 2)
    formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Remove extra spaces around punctuation marks
    formatted = formatted.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), '\$1');
    formatted = formatted.replaceAll(RegExp(r'([(\[«])\s+'), '\$1');

    // Add space after punctuation if missing (both Latin and Cyrillic)
    formatted = formatted.replaceAll(RegExp(r'\.([a-zA-Zа-яА-ЯёЁ])'), '. \$1');
    formatted = formatted.replaceAll(RegExp(r',([a-zA-Zа-яА-ЯёЁ])'), ', \$1');
    formatted = formatted.replaceAll(RegExp(r';([a-zA-Zа-яА-ЯёЁ])'), '; \$1');
    formatted = formatted.replaceAll(RegExp(r':([a-zA-Zа-яА-ЯёЁ])'), ': \$1');
    formatted = formatted.replaceAll(RegExp(r'!([a-zA-Zа-яА-ЯёЁ])'), '! \$1');
    formatted = formatted.replaceAll(RegExp(r'\?([a-zA-Zа-яА-ЯёЁ])'), '? \$1');

    // Russian quotation marks fixes
    formatted = formatted.replaceAll(RegExp(r'«\s+'), '«');
    formatted = formatted.replaceAll(RegExp(r'\s+»'), '»');

    // Replace multiple hyphens or em-dashes with single em dash
    formatted = formatted.replaceAll(RegExp(r'\s*[-–—]+\s*'), ' — ');

    // Remove any remaining double spaces
    formatted = formatted.replaceAll(RegExp(r' {2,}'), ' ');

    // Add soft hyphens for word breaking (hyphenation)
    formatted = _addSoftHyphens(formatted);

    return formatted.trim();
  }

  // Add soft hyphens to allow proper word breaking with hyphens
  String _addSoftHyphens(String text) {
    // Split into words and add soft hyphens to long words
    return text.replaceAllMapped(RegExp(r'\b[\w\u0400-\u04FF]{8,}\b'), (match) {
      String word = match.group(0)!;
      // Don't hyphenate if word already contains hyphens or soft hyphens
      if (word.contains('-') || word.contains('\u00AD')) return word;

      // Check if word is Russian (Cyrillic) or English
      bool isRussian = RegExp(r'[\u0400-\u04FF]').hasMatch(word);

      StringBuffer result = StringBuffer();
      for (int i = 0; i < word.length; i++) {
        result.write(word[i]);

        // Russian hyphenation rules
        if (isRussian && i > 2 && i < word.length - 2) {
          // Add soft hyphen after consonants before vowels in Russian
          String current = word[i];
          String next = i < word.length - 1 ? word[i + 1] : '';

          bool currentIsConsonant = RegExp(r'[бвгджзклмнпрстфхцчшщБВГДЖЗКЛМНПРСТФХЦЧШЩ]').hasMatch(current);
          bool nextIsVowel = RegExp(r'[аэоуиыяюеёАЭОУИЫЯЮЕЁ]').hasMatch(next);

          if (currentIsConsonant && nextIsVowel && (i % 3 == 0 || i % 4 == 0)) {
            result.write('\u00AD'); // Soft hyphen
          }
        }
        // English hyphenation rules
        else if (!isRussian && i > 3 && i < word.length - 3) {
          // Add soft hyphen after vowels when word is long enough
          if ((i % 4 == 0 || i % 5 == 0) && 'aeiouAEIOU'.contains(word[i])) {
            result.write('\u00AD'); // Soft hyphen
          }
        }
      }
      return result.toString();
    });
  }

  Widget _buildFormattedText(String text, TextStyle style) {
    final formattedText = _formatText(text);
    final paragraphs = formattedText.split('\n\n');

    List<InlineSpan> spans = [];

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) continue;

      // Add paragraph indent (using em-space for first line)
      spans.add(TextSpan(
        text: '\u2003$paragraph',
        style: style.copyWith(
          fontFamily: 'SFPro',
          height: 1.5,
          letterSpacing: 0,
          wordSpacing: 0,
          fontSize: style.fontSize,
        ),
      ));

      // Add proper paragraph break (except for last paragraph)
      if (i < paragraphs.length - 1) {
        spans.add(TextSpan(text: '\n\n'));
      }
    }

    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        children: spans,
        style: style.copyWith(
          fontFamily: 'SFPro',
          height: 1.5,
          letterSpacing: 0,
          wordSpacing: 0,
        ),
      ),
    );
  }

  void _handleAddNote(BuildContext context, String selectedText) async {
    _showAddNoteBottomSheet(context, selectedText);
  }

  void _showAddNoteBottomSheet(BuildContext context, String selectedText) {
    final textController = TextEditingController(text: '');
    final selectedColor = Colors.blue.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Obx(() => Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CosmosEpubLocalization.t('note'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () async {
                            final note = textController.text.trim();
                            Navigator.pop(context);
                            await CosmosEpub.addNote(
                              bookId: bookId,
                              selectedText: note.isEmpty ? selectedText : '$selectedText\n\n$note',
                              context: context,
                            );
                          },
                          child: Text(
                            CosmosEpubLocalization.t('done'),
                            style: TextStyle(
                              fontSize: 17,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Selected text display with left border
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: selectedColor.value,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Text(
                      selectedText,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  // Note input with left border
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.only(left: 12),
                      child: TextField(
                        controller: textController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: CosmosEpubLocalization.t('add_note_hint'),
                        ),
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  // Color picker - always visible above keyboard
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Colors.grey,
                        Colors.red,
                        Colors.amber,
                        Colors.brown,
                        Colors.purple,
                        Colors.green,
                        Colors.blue,
                      ]
                          .map((color) => GestureDetector(
                                onTap: () => selectedColor.value = color,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: selectedColor.value == color
                                        ? Border.all(
                                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            )),
      ),
    );
  }

  void _handleShare(BuildContext context, String selectedText) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.localToGlobal(Offset.zero) & box.size;

    SharePlus.instance.share(
      ShareParams(
        text: selectedText,
        sharePositionOrigin: position,
      ),
    );
  }
}

class BookPageBuilder {
  static Widget buildBookPage({
    required String text,
    required TextStyle style,
    required TextDirection textDirection,
    required String bookId,
    required VoidCallback onTextTap,
    bool isFirstPage = false,
    String? chapterTitle,
    int? pageNumber,
    int? totalPages,
    Color? backgroundColor,
    double bottomNavHeight = 70.0,
  }) {
    return GestureDetector(
      onTap: onTextTap,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: backgroundColor ?? const Color(0xFFFFFFFF),
        padding: EdgeInsets.only(
          left: 18.w,
          right: 18.w,
          top: 20.h,
          bottom: 20.h,
        ),
        child: SingleChildScrollView(
          child: SelectableTextWithCustomToolbar(
            text: text,
            textDirection: textDirection,
            style: style,
            bookId: bookId,
            isFirstPage: isFirstPage,
            chapterTitle: chapterTitle,
            pageNumber: pageNumber,
            totalPages: totalPages,
          ),
        ),
      ),
    );
  }

  /// Check if page content is primarily quote/poetry style (italic, centered)
  /// If entire page is quote-like, it should be vertically centered
  static bool _isQuoteOnlyPage(TextSpan contentSpan) {
    final children = contentSpan.children;
    if (children == null || children.isEmpty) return false;

    int totalMeaningfulSpans = 0;
    int quoteSpans = 0;

    for (final span in children) {
      if (span is TextSpan) {
        final text = span.text ?? '';
        // Skip empty or whitespace-only spans
        if (text.trim().isEmpty) continue;

        // Skip section dividers - they are neutral
        if (_isSectionDivider(text)) {
          continue;
        }

        totalMeaningfulSpans++;
        // TextSpans are regular content, not quotes
      } else if (span is WidgetSpan) {
        final widget = span.child;

        // Skip SizedBox - they are just spacing, not content
        if (widget is SizedBox) {
          continue;
        }

        totalMeaningfulSpans++;

        if (widget is Container) {
          // Check if container has centered alignment (quote style)
          if (widget.alignment == Alignment.centerRight || widget.alignment == Alignment.center) {
            quoteSpans++;
          }
          // Check margin - quotes often have left margin
          else {
            final margin = widget.margin;
            if (margin is EdgeInsets && margin.left > 20) {
              quoteSpans++;
            }
          }
        }
      }
    }

    // If no meaningful content spans found, not a quote page
    if (totalMeaningfulSpans == 0) return false;

    // If more than 70% of meaningful content is quote-style, center the page
    final isQuoteOnly = quoteSpans / totalMeaningfulSpans > 0.7;
    return isQuoteOnly;
  }

  /// Helper method to check if a WidgetSpan represents a quote/poetry element
  static bool _isQuoteWidgetSpan(WidgetSpan widgetSpan) {
    final widget = widgetSpan.child;

    if (widget is Container) {
      // Check alignment
      if (widget.alignment == Alignment.centerRight || widget.alignment == Alignment.center) {
        return true;
      }
      // Check margin - quotes often have left margin
      final margin = widget.margin;
      if (margin is EdgeInsets && margin.left > 20) {
        return true;
      }
    } else if (widget is SizedBox) {
      // SizedBox alone is not a quote, but can be part of quote section
      return false;
    } else {}

    return false;
  }

  /// Convert quote spans to be centered (change centerRight to center alignment)
  static TextSpan _centerQuoteSpans(TextSpan contentSpan) {
    final children = contentSpan.children;
    if (children == null || children.isEmpty) {
      return contentSpan;
    }

    List<InlineSpan> centeredChildren = [];
    for (final span in children) {
      if (span is WidgetSpan) {
        final widget = span.child;
        if (widget is Container) {
          // Replace centerRight with center alignment and remove left margin
          if (widget.alignment == Alignment.centerRight) {
            centeredChildren.add(WidgetSpan(
              alignment: span.alignment,
              baseline: span.baseline,
              child: Container(
                width: widget.constraints?.maxWidth ?? double.infinity,
                alignment: Alignment.center, // Center instead of centerRight
                padding: widget.padding,
                child: widget.child,
              ),
            ));
            continue;
          }
        }
        centeredChildren.add(span);
      } else {
        centeredChildren.add(span);
      }
    }

    return TextSpan(children: centeredChildren, style: contentSpan.style);
  }

  /// Check if text is a section divider (like "* * *", "***", "---", Roman numerals, etc.)
  static bool _isSectionDivider(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Common section divider patterns
    if (trimmed == '* * *' ||
        trimmed == '***' ||
        trimmed == '---' ||
        trimmed == '* * * *' ||
        trimmed == '----' ||
        trimmed == '————' ||
        trimmed == '***' ||
        trimmed == '• • •' ||
        trimmed == '...' ||
        RegExp(r'^[\*\-•\.—–\s]+$').hasMatch(trimmed)) {
      return true;
    }

    // Roman numerals (I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII, etc.)
    // Supports uppercase and lowercase, with optional period or parenthesis
    if (RegExp(r'^[IVXLCDM]+\.?$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^\([IVXLCDM]+\)$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^[IVXLCDM]+\)$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Arabic numerals as section dividers (1, 2, 3, etc. or 1., 2., 3., etc.)
    if (RegExp(r'^\d+\.?$').hasMatch(trimmed) || RegExp(r'^\(\d+\)$').hasMatch(trimmed) || RegExp(r'^\d+\)$').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Check if page has regular text followed by a quote at the end
  /// Returns split info: (hasTextThenQuote, regularContentSpans, quoteContentSpans)
  static ({bool hasTextThenQuote, List<InlineSpan> regularContent, List<InlineSpan> quoteContent}) _analyzePageContent(TextSpan contentSpan) {
    final children = contentSpan.children;
    if (children == null || children.isEmpty) {
      return (hasTextThenQuote: false, regularContent: [], quoteContent: []);
    }

    // Debug: Print all spans
    for (int i = 0; i < children.length; i++) {
      final span = children[i];
      if (span is WidgetSpan) {
      } else if (span is TextSpan) {
        // final text = span.text ?? '';
        // final hasChildren = span.children?.isNotEmpty ?? false;
        // final isItalic = span.style?.fontStyle == FontStyle.italic;
        // final isDivider = _isSectionDivider(text);
      }
    }

    // Find quote spans from the end
    int quoteStartIndex = -1;
    int lastNonEmptyIndex = -1;

    // First, find the last non-empty span (excluding section dividers)
    for (int i = children.length - 1; i >= 0; i--) {
      final span = children[i];
      if (span is WidgetSpan) {
        if (span.child is! SizedBox) {
          lastNonEmptyIndex = i;
          break;
        }
      } else if (span is TextSpan) {
        final text = span.text ?? '';
        // Skip section dividers like "* * *"
        if (_isSectionDivider(text)) {
          continue;
        }
        if (text.trim().isNotEmpty || (span.children?.isNotEmpty ?? false)) {
          lastNonEmptyIndex = i;
          break;
        }
      }
    }

    if (lastNonEmptyIndex < 0) {
      return (hasTextThenQuote: false, regularContent: [], quoteContent: []);
    }

    // Now check from the last non-empty span backwards to find quote section
    bool inQuoteSection = false;

    for (int i = lastNonEmptyIndex; i >= 0; i--) {
      final span = children[i];
      bool isQuote = false;

      if (span is WidgetSpan) {
        // SizedBox is neutral - include in quote section if we're in one
        if (span.child is SizedBox) {
          if (inQuoteSection) {
            continue; // Include SizedBox in quote section
          } else {
            continue; // Skip SizedBox before finding quote
          }
        }
        isQuote = _isQuoteWidgetSpan(span);
      } else if (span is TextSpan) {
        final text = span.text ?? '';

        // Section dividers are neutral - include in quote section if we're in one
        if (_isSectionDivider(text)) {
          if (inQuoteSection) {
            continue;
          } else {
            continue;
          }
        }

        // Skip whitespace-only spans
        if (text.trim().isEmpty && (span.children == null || span.children!.isEmpty)) {
          if (inQuoteSection) {
            continue;
          } else {
            continue;
          }
        }
        // TextSpan is regular content, not quote
        isQuote = false;
      }

      if (isQuote) {
        inQuoteSection = true;
        quoteStartIndex = i;
      } else if (inQuoteSection) {
        // Found non-quote content - this is the split point
        break;
      }
    }

    // Must have found quote section and have content before it
    if (quoteStartIndex <= 0) {
      return (hasTextThenQuote: false, regularContent: [], quoteContent: []);
    }

    // Check if there's meaningful regular (non-quote, non-divider) content before the quote
    bool hasRegularContent = false;
    for (int i = 0; i < quoteStartIndex; i++) {
      final span = children[i];
      if (span is TextSpan) {
        final text = span.text ?? '';

        // Skip section dividers
        if (_isSectionDivider(text)) {
          continue;
        }

        // Check direct text - must be substantial (more than just punctuation/short)
        if (text.trim().isNotEmpty && text.trim().length > 10) {
          hasRegularContent = true;
          break;
        }
        // Check nested children
        if (span.children != null) {
          for (var child in span.children!) {
            if (child is TextSpan) {
              final childText = child.text ?? '';
              if (childText.trim().isNotEmpty && childText.trim().length > 10 && !_isSectionDivider(childText)) {
                hasRegularContent = true;
                break;
              }
            }
          }
          if (hasRegularContent) break;
        }
      } else if (span is WidgetSpan) {
        // WidgetSpan with non-quote content (but NOT quote containers)
        if (!_isQuoteWidgetSpan(span) && span.child is! SizedBox) {
          // Check if this is a paragraph container (not a quote)
          final widget = span.child;
          if (widget is Container) {
            // If container has centerRight alignment, it's a quote, skip it
            if (widget.alignment == Alignment.centerRight || widget.alignment == Alignment.center) {
              continue;
            }
          }
          hasRegularContent = true;
          break;
        }
      }
    }

    if (!hasRegularContent) {
      return (hasTextThenQuote: false, regularContent: [], quoteContent: []);
    }

    // Split content
    final regularContent = children.sublist(0, quoteStartIndex).cast<InlineSpan>().toList();
    final quoteContent = children.sublist(quoteStartIndex).cast<InlineSpan>().toList();

    return (hasTextThenQuote: true, regularContent: regularContent, quoteContent: quoteContent);
  }

  // NEW METHOD: Build page with TextSpan (for mixed text + images)
  static Widget buildBookPageSpan({
    required BuildContext context,
    required TextSpan contentSpan,
    required TextStyle style,
    required TextDirection textDirection,
    required String bookId,
    required VoidCallback onTextTap,
    bool isFirstPage = false,
    String? chapterTitle,
    int? pageNumber,
    int? totalPages,
    Color? backgroundColor,
    double bottomNavHeight = 70.0,
  }) {
    final bgColor = backgroundColor ?? const Color(0xFFFFFFFF);

    // Check if this page is quote-only (should be vertically centered)
    final isQuoteOnlyPage = _isQuoteOnlyPage(contentSpan);

    // Check if page has regular text followed by a quote at the end
    final pageAnalysis = _analyzePageContent(contentSpan);
    final hasTextThenQuote = pageAnalysis.hasTextThenQuote;

    return GestureDetector(
        onTap: onTextTap,
        behavior: HitTestBehavior.translucent,
        child: Container(
          // Tam ekran yüksekliği
          height: double.infinity,
          width: double.infinity,
          // DEBUG: Add colored border to see page boundaries
          decoration: BoxDecoration(
            color: bgColor,
          ),
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 8.h,
            bottom: 16.h,
          ),
          child: Directionality(
            textDirection: textDirection,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // If page has text followed by quote, create split layout
                if (hasTextThenQuote) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Chapter title header on ALL pages
                      if (chapterTitle != null) ...[
                        if (isFirstPage) ...[
                          SizedBox(height: 4.h),
                          Text(
                            chapterTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: style.copyWith(
                              fontSize: (style.fontSize ?? 16) + 2,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                              letterSpacing: 0.1,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 6.h),
                        ] else ...[
                          SizedBox(height: 2.h),
                          Text(
                            chapterTitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style.copyWith(
                              fontSize: (style.fontSize ?? 16) - 2,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 4.h),
                        ],
                      ],

                      // Regular text content at top
                      Selectable(
                        selectWordOnLongPress: true,
                        selectWordOnDoubleTap: true,
                        selectionColor: const Color(0xFFB8B3E9).withValues(alpha: 0.5),
                        popupMenuItems: _buildPopupMenuItems(context, bookId),
                        child: RichText(
                          textAlign: TextAlign.left,
                          text: TextSpan(children: pageAnalysis.regularContent),
                        ),
                      ),

                      // Quote content centered in remaining space
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          child: Selectable(
                            selectWordOnLongPress: true,
                            selectWordOnDoubleTap: true,
                            selectionColor: const Color(0xFFB8B3E9).withValues(alpha: 0.5),
                            popupMenuItems: _buildPopupMenuItems(context, bookId),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(children: pageAnalysis.quoteContent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Standard layout for other pages
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Chapter title header on ALL pages
                    if (chapterTitle != null) ...[
                      if (isFirstPage) ...[
                        SizedBox(height: 4.h), // Reduced from 8h
                        Text(
                          chapterTitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(
                            fontSize: (style.fontSize ?? 16) - 2, // Smaller title
                            fontWeight: FontWeight.w400,
                            height: 1.0, // Tighter spacing

                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10.h), // Reduced from 10h
                      ] else ...[
                        SizedBox(height: 2.h), // Reduced from 4h
                        Text(
                          chapterTitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(
                            fontSize: (style.fontSize ?? 16) - 2,
                            fontWeight: FontWeight.w400,
                            height: 1.0, // Tighter spacing
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10.h), // Reduced from 6h
                      ],
                    ],

                    // Main content - fill remaining space completely
                    // If quote-only page, center vertically; otherwise top-align
                    Expanded(
                      child: Container(
                        alignment: isQuoteOnlyPage ? Alignment.center : Alignment.topLeft,
                        child: Selectable(
                          selectWordOnLongPress: true,
                          selectWordOnDoubleTap: true,
                          selectionColor: const Color(0xFFB8B3E9).withValues(alpha: 0.5),
                          popupMenuItems: _buildPopupMenuItems(context, bookId),
                          // For quote-only pages, don't force full height - let alignment work
                          child: isQuoteOnlyPage
                              ? SizedBox(
                                  width: double.infinity,
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: _centerQuoteSpans(contentSpan),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Container(
                                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                      child: RichText(
                                        textAlign: TextAlign.left,
                                        text: contentSpan,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    // Bottom spacer kaldırıldı - padding zaten var
                  ],
                );
              },
            ),
          ),
        ));
  }

  /// Build popup menu items for text selection
  static List<SelectableMenuItem> _buildPopupMenuItems(BuildContext context, String bookId) {
    return [
      SelectableMenuItem(
        title: CosmosEpubLocalization.t('add_note'),
        isEnabled: (controller) => controller!.isTextSelected,
        handler: (controller) {
          final selectedText = controller!.getSelection()!.text!;
          _handleAddNoteFromSpan(context, bookId, selectedText);
          return true;
        },
      ),
      SelectableMenuItem(
        title: CosmosEpubLocalization.t('share'),
        isEnabled: (controller) => controller!.isTextSelected,
        handler: (controller) {
          final selectedText = controller!.getSelection()!.text!;

          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return true;

          final position = box.localToGlobal(Offset.zero) & box.size;

          SharePlus.instance.share(
            ShareParams(
              text: selectedText,
              sharePositionOrigin: position,
            ),
          );
          return true;
        },
      ),
      SelectableMenuItem(
        type: SelectableMenuItemType.copy,
        title: CosmosEpubLocalization.t('copy'),
      ),
    ];
  }

  static Future<void> _handleAddNoteFromSpan(BuildContext context, String bookId, String selectedText) async {
    _showAddNoteBottomSheetFromSpan(context, bookId, selectedText);
  }

  static void _showAddNoteBottomSheetFromSpan(BuildContext context, String bookId, String selectedText) {
    final textController = TextEditingController(text: '');
    final selectedColor = Colors.blue.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Obx(() => Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CosmosEpubLocalization.t('note'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () async {
                            final note = textController.text.trim();
                            Navigator.pop(context);
                            await CosmosEpub.addNote(
                              bookId: bookId,
                              selectedText: note.isEmpty ? selectedText : '$selectedText\n\n$note',
                              context: context,
                            );
                          },
                          child: Text(
                            CosmosEpubLocalization.t('done'),
                            style: TextStyle(
                              fontSize: 17,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Selected text display with left border
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: selectedColor.value,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Text(
                      selectedText,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  // Note input with left border
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.only(left: 12),
                      child: TextField(
                        controller: textController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: CosmosEpubLocalization.t('add_note_hint'),
                        ),
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ),

                  // Color picker - always visible above keyboard
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Colors.grey,
                        Colors.red,
                        Colors.amber,
                        Colors.brown,
                        Colors.purple,
                        Colors.green,
                        Colors.blue,
                      ]
                          .map((color) => GestureDetector(
                                onTap: () => selectedColor.value = color,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: selectedColor.value == color
                                        ? Border.all(
                                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            )),
      ),
    );
  }

  static String cleanBookText(String htmlText) {
    String cleaned = htmlText.replaceAll(RegExp(r'<[^>]*>'), '');

    // HTML entity decoding
    cleaned = cleaned
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»');

    // Remove Unicode invisible characters
    cleaned = cleaned.replaceAll('\u00A0', ' '); // Non-breaking space
    cleaned = cleaned.replaceAll('\u200B', ''); // Zero-width space
    cleaned = cleaned.replaceAll('\u2009', ' '); // Thin space
    cleaned = cleaned.replaceAll('\u202F', ' '); // Narrow no-break space
    cleaned = cleaned.replaceAll('\uFEFF', ''); // Zero-width no-break space

    // Remove excessive spaces
    cleaned = cleaned.replaceAll(RegExp(r'[ \t\u00A0\u200B\u2009\u202F]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');

    // Clean up line breaks
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r'^\s+', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+$', multiLine: true), '');

    return cleaned.trim();
  }
}
