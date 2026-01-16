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
    return Selectable(
      selectWordOnLongPress: true,
      selectWordOnDoubleTap: true,
      selectionColor: const Color(0xFFB8B3E9).withValues(alpha: 0.5),
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

    int totalSpans = 0;
    int quoteSpans = 0;

    for (final span in children) {
      if (span is TextSpan) {
        final text = span.text ?? '';
        // Skip empty or whitespace-only spans
        if (text.trim().isEmpty) continue;

        totalSpans++;

        // Check if this span has italic style (typical for quotes)
        if (span.style?.fontStyle == FontStyle.italic) {
          quoteSpans++;
        }
      } else if (span is WidgetSpan) {
        // WidgetSpans are often used for quote formatting
        final widget = span.child;
        if (widget is Container) {
          // Check if container has centered alignment (quote style)
          if (widget.alignment == Alignment.centerRight || widget.alignment == Alignment.center) {
            quoteSpans++;
          }
        }
        totalSpans++;
      }
    }

    // If no content spans found, not a quote page
    if (totalSpans == 0) return false;

    // If more than 70% of content is quote-style, center the page
    return quoteSpans / totalSpans > 0.7;
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
                            fontSize: (style.fontSize ?? 16) + 2, // Smaller title
                            fontWeight: FontWeight.w500,
                            height: 1.1, // Tighter spacing
                            letterSpacing: 0.1,
                          ),
                        ),
                        SizedBox(height: 6.h), // Reduced from 10h
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
                            color: (style.color ?? Colors.black).withValues(alpha: 0.5),
                          ),
                        ),
                        SizedBox(height: 4.h), // Reduced from 6h
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
                          popupMenuItems: [
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
                          ],
                          child: LayoutBuilder(
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
