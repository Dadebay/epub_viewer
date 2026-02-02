import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:selectable/selectable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class SelectableTextWithCustomToolbar extends StatelessWidget {
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

  final String bookId;
  final String? chapterTitle;
  final bool isFirstPage;
  final int? pageNumber;
  final TextStyle style;
  final String text;
  final TextDirection textDirection;
  final int? totalPages;

  String _formatText(String rawText) {
    if (rawText.isEmpty) return rawText;

    String formatted = rawText;

    formatted = formatted.replaceAll('\u00A0', ' ');
    formatted = formatted.replaceAll('\u200B', '');
    formatted = formatted.replaceAll('\u2009', ' ');
    formatted = formatted.replaceAll('\u202F', ' ');
    formatted = formatted.replaceAll(RegExp(r'[ \t\u00A0\u200B\u2009\u202F]+'), ' ');

    formatted = formatted.replaceAll(RegExp(r'^\s+', multiLine: true), '');
    formatted = formatted.replaceAll(RegExp(r'\s+$', multiLine: true), '');

    formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    formatted = formatted.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), '\$1');
    formatted = formatted.replaceAll(RegExp(r'([(\[«])\s+'), '\$1');

    formatted = formatted.replaceAll(RegExp(r'\.([a-zA-Zа-яА-ЯёЁ])'), '. \$1');
    formatted = formatted.replaceAll(RegExp(r',([a-zA-Zа-яА-ЯёЁ])'), ', \$1');
    formatted = formatted.replaceAll(RegExp(r';([a-zA-Zа-яА-ЯёЁ])'), '; \$1');
    formatted = formatted.replaceAll(RegExp(r':([a-zA-Zа-яА-ЯёЁ])'), ': \$1');
    formatted = formatted.replaceAll(RegExp(r'!([a-zA-Zа-яА-ЯёЁ])'), '! \$1');
    formatted = formatted.replaceAll(RegExp(r'\?([a-zA-Zа-яА-ЯёЁ])'), '? \$1');

    formatted = formatted.replaceAll(RegExp(r'«\s+'), '«');
    formatted = formatted.replaceAll(RegExp(r'\s+»'), '»');

    formatted = formatted.replaceAll(RegExp(r'\s*[-–—]+\s*'), ' — ');

    formatted = formatted.replaceAll(RegExp(r' {2,}'), ' ');

    formatted = _addSoftHyphens(formatted);

    return formatted.trim();
  }

  String _addSoftHyphens(String text) {
    return text.replaceAllMapped(RegExp(r'\b[\w\u0400-\u04FF]{8,}\b'), (match) {
      String word = match.group(0)!;

      if (word.contains('-') || word.contains('\u00AD')) return word;

      bool isRussian = RegExp(r'[\u0400-\u04FF]').hasMatch(word);

      StringBuffer result = StringBuffer();
      for (int i = 0; i < word.length; i++) {
        result.write(word[i]);

        if (isRussian && i > 2 && i < word.length - 2) {
          String current = word[i];
          String next = i < word.length - 1 ? word[i + 1] : '';

          bool currentIsConsonant = RegExp(r'[бвгджзклмнпрстфхцчшщБВГДЖЗКЛМНПРСТФХЦЧШЩ]').hasMatch(current);
          bool nextIsVowel = RegExp(r'[аэоуиыяюеёАЭОУИЫЯЮЕЁ]').hasMatch(next);

          if (currentIsConsonant && nextIsVowel && (i % 3 == 0 || i % 4 == 0)) {
            result.write('\u00AD');
          }
        } else if (!isRussian && i > 3 && i < word.length - 3) {
          if ((i % 4 == 0 || i % 5 == 0) && 'aeiouAEIOU'.contains(word[i])) {
            result.write('\u00AD');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final menuBackgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

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
        cardTheme: CardTheme(
          color: menuBackgroundColor,
          elevation: 8,
          shadowColor: isDark ? Colors.white12 : Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textButtonTheme: TextButtonThemeData(style: customButtonStyle),
        elevatedButtonTheme: ElevatedButtonThemeData(style: customButtonStyle),
        filledButtonTheme: FilledButtonThemeData(style: customButtonStyle),
        popupMenuTheme: PopupMenuThemeData(
          color: menuBackgroundColor,
          elevation: 8,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
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
              _buildFormattedText(text, style),
            ],
          ),
        ),
      ),
    );
  }
}

class BookPageBuilder {
  static ({bool hasTextThenQuote, List<InlineSpan> regularContent, List<InlineSpan> quoteContent}) _analyzePageContent(TextSpan contentSpan) {
    final children = contentSpan.children;
    if (children == null || children.isEmpty) {
      return (hasTextThenQuote: false, regularContent: [], quoteContent: []);
    }

    for (int i = 0; i < children.length; i++) {
      final span = children[i];
      if (span is WidgetSpan) {
      } else if (span is TextSpan) {}
    }

    int quoteStartIndex = -1;
    int lastNonEmptyIndex = -1;

    for (int i = children.length - 1; i >= 0; i--) {
      final span = children[i];
      if (span is WidgetSpan) {
        if (span.child is! SizedBox) {
          lastNonEmptyIndex = i;
          break;
        }
      } else if (span is TextSpan) {
        final text = span.text ?? '';

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

    bool inQuoteSection = false;

    for (int i = lastNonEmptyIndex; i >= 0; i--) {
      final span = children[i];
      bool isQuote = false;

      if (span is WidgetSpan) {
        if (span.child is SizedBox) {
          if (inQuoteSection) {
            continue;
          } else {
            continue;
          }
        }
        isQuote = _isQuoteWidgetSpan(span);
      } else if (span is TextSpan) {
        final text = span.text ?? '';

        if (_isSectionDivider(text)) {
          if (inQuoteSection) {
            continue;
          } else {
            continue;
          }
        }

        if (text.trim().isEmpty && (span.children == null || span.children!.isEmpty)) {
          if (inQuoteSection) {
            continue;
          } else {
            continue;
          }
        }

        isQuote = false;
      }

      if (isQuote) {
        inQuoteSection = true;
        quoteStartIndex = i;
      } else if (inQuoteSection) {
        break;
      }
    }

    if (quoteStartIndex <= 0) {
      return (hasTextThenQuote: false, regularContent: [], quoteContent: []);
    }

    bool hasRegularContent = false;
    for (int i = 0; i < quoteStartIndex; i++) {
      final span = children[i];
      if (span is TextSpan) {
        final text = span.text ?? '';

        if (_isSectionDivider(text)) {
          continue;
        }

        if (text.trim().isNotEmpty && text.trim().length > 10) {
          hasRegularContent = true;
          break;
        }

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
        if (!_isQuoteWidgetSpan(span) && span.child is! SizedBox) {
          final widget = span.child;
          if (widget is Container) {
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

    final regularContent = children.sublist(0, quoteStartIndex).cast<InlineSpan>().toList();
    final quoteContent = children.sublist(quoteStartIndex).cast<InlineSpan>().toList();

    return (hasTextThenQuote: true, regularContent: regularContent, quoteContent: quoteContent);
  }

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

    final isQuoteOnlyPage = _isQuoteOnlyPage(contentSpan);

    final pageAnalysis = _analyzePageContent(contentSpan);
    final hasTextThenQuote = pageAnalysis.hasTextThenQuote;

    return GestureDetector(
        onTap: onTextTap,
        behavior: HitTestBehavior.translucent,
        child: Container(
          height: double.infinity,
          width: double.infinity,
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
                if (hasTextThenQuote) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.max,
                    children: [
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (chapterTitle != null) ...[
                      if (isFirstPage) ...[
                        SizedBox(height: 4.h),
                        Text(
                          chapterTitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(
                            fontSize: (style.fontSize ?? 16) - 2,
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10.h),
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
                        SizedBox(height: 10.h),
                      ],
                    ],
                    Expanded(
                      child: Container(
                        alignment: isQuoteOnlyPage ? Alignment.center : Alignment.topLeft,
                        child: Selectable(
                          selectWordOnLongPress: true,
                          selectWordOnDoubleTap: true,
                          selectionColor: const Color(0xFFB8B3E9).withValues(alpha: 0.5),
                          popupMenuItems: _buildPopupMenuItems(context, bookId),
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
                  ],
                );
              },
            ),
          ),
        ));
  }

  static String cleanBookText(String htmlText) {
    String cleaned = htmlText.replaceAll(RegExp(r'<[^>]*>'), '');

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

    cleaned = cleaned.replaceAll('\u00A0', ' ');
    cleaned = cleaned.replaceAll('\u200B', '');
    cleaned = cleaned.replaceAll('\u2009', ' ');
    cleaned = cleaned.replaceAll('\u202F', ' ');
    cleaned = cleaned.replaceAll('\uFEFF', '');

    cleaned = cleaned.replaceAll(RegExp(r'[ \t\u00A0\u200B\u2009\u202F]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');

    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r'^\s+', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+$', multiLine: true), '');

    return cleaned.trim();
  }

  static bool _isQuoteOnlyPage(TextSpan contentSpan) {
    final children = contentSpan.children;
    if (children == null || children.isEmpty) return false;

    int totalMeaningfulSpans = 0;
    int quoteSpans = 0;

    for (final span in children) {
      if (span is TextSpan) {
        final text = span.text ?? '';

        if (text.trim().isEmpty) continue;

        if (_isSectionDivider(text)) {
          continue;
        }

        totalMeaningfulSpans++;
      } else if (span is WidgetSpan) {
        final widget = span.child;

        if (widget is SizedBox) {
          continue;
        }

        totalMeaningfulSpans++;

        if (widget is Container) {
          if (widget.alignment == Alignment.centerRight || widget.alignment == Alignment.center) {
            quoteSpans++;
          } else {
            final margin = widget.margin;
            if (margin is EdgeInsets && margin.left > 20) {
              quoteSpans++;
            }
          }
        }
      }
    }

    if (totalMeaningfulSpans == 0) return false;

    final isQuoteOnly = quoteSpans / totalMeaningfulSpans > 0.7;
    return isQuoteOnly;
  }

  static bool _isQuoteWidgetSpan(WidgetSpan widgetSpan) {
    final widget = widgetSpan.child;

    if (widget is Container) {
      if (widget.alignment == Alignment.centerRight || widget.alignment == Alignment.center) {
        return true;
      }

      final margin = widget.margin;
      if (margin is EdgeInsets && margin.left > 20) {
        return true;
      }
    } else if (widget is SizedBox) {
      return false;
    } else {}

    return false;
  }

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
          if (widget.alignment == Alignment.centerRight) {
            centeredChildren.add(WidgetSpan(
              alignment: span.alignment,
              baseline: span.baseline,
              child: Container(
                width: widget.constraints?.maxWidth ?? double.infinity,
                alignment: Alignment.center,
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

  static bool _isSectionDivider(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

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

    if (RegExp(r'^[IVXLCDM]+\.?$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^\([IVXLCDM]+\)$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^[IVXLCDM]+\)$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    if (RegExp(r'^\d+\.?$').hasMatch(trimmed) || RegExp(r'^\(\d+\)$').hasMatch(trimmed) || RegExp(r'^\d+\)$').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

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
}
