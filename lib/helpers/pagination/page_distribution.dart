import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Handles page distribution and splitting of content
class PageDistributor {
  final TextStyle contentStyle;
  final bool isFrontMatter;

  // Map to store which subchapter appears on which page (0-indexed page number)
  final Map<String, int> subchapterPageMap = {};

  PageDistributor({
    required this.contentStyle,
    required this.isFrontMatter,
  });

  /// Distributes spans across multiple pages based on character limits
  List<TextSpan> distributeContent(List<InlineSpan> allSpans, Size pageSize) {
    subchapterPageMap.clear(); // Clear previous mapping

    List<InlineSpan> flatSpans = _flattenSpans(allSpans);

    final metrics = _calculateMetrics(flatSpans, pageSize);

    // If content fits in single page - BALANCED
    if (metrics.pageRatio <= 1.0 && metrics.totalChars <= 1600) {
      // Check for subchapters even in single page
      _detectSubchaptersInSpans(flatSpans, 0);
      return [TextSpan(children: List.from(flatSpans))];
    }

    return _distributeToPages(flatSpans, metrics);
  }

  List<InlineSpan> _flattenSpans(List<InlineSpan> allSpans) {
    List<InlineSpan> flatSpans = [];

    void flatten(InlineSpan span, {TextStyle? inheritedStyle}) {
      if (span is TextSpan) {
        final effectiveStyle = inheritedStyle != null ? inheritedStyle.merge(span.style) : span.style;

        if (span.children != null && span.children!.isNotEmpty) {
          for (var child in span.children!) {
            flatten(child, inheritedStyle: effectiveStyle);
          }
        } else if (span.text != null && span.text!.isNotEmpty) {
          // Preserve semanticsLabel when flattening - critical for subchapter detection
          flatSpans.add(TextSpan(
            text: span.text,
            style: effectiveStyle,
            semanticsLabel: span.semanticsLabel, // PRESERVE THIS!
          ));
        }
      } else if (span is WidgetSpan) {
        flatSpans.add(span);
      }
    }

    for (var s in allSpans) {
      flatten(s);
    }
    return flatSpans;
  }

  _PageMetrics _calculateMetrics(List<InlineSpan> flatSpans, Size pageSize) {
    double horizontalPadding = 10.w;
    if (pageSize.width >= 600) {
      horizontalPadding = 20.w;
    }
    double maxWidth = pageSize.width - horizontalPadding;

    // BALANCED: İyi doluluk + güvenli alt margin
    double containerPadding = isFrontMatter ? 10.h : 16.h;
    double chapterHeaderSpace = isFrontMatter ? 6.h : 12.h;
    double bottomSafeArea = isFrontMatter ? 6.h : 10.h;
    double reservedSpace = containerPadding + chapterHeaderSpace + bottomSafeArea;
    double maxHeight = pageSize.height - reservedSpace;
    // Güvenli yükseklik payı (%94) - son satır kesilmesini önler
    maxHeight = maxHeight * 0.94;

    double totalContentHeight = 0;
    int totalChars = 0;

    for (var span in flatSpans) {
      if (span is TextSpan && span.text != null) {
        totalChars += span.text!.length;
      }
      if (span is WidgetSpan) {
        try {
          TextPainter painter = TextPainter(
            text: TextSpan(children: [span]),
            textDirection: TextDirection.ltr,
            textScaleFactor: 1.0,
          );
          painter.layout(maxWidth: maxWidth);
          totalContentHeight += painter.height;
          painter.dispose();
        } catch (e) {
          totalContentHeight += 100.h;
        }
      } else if (span is TextSpan && span.text != null) {
        TextPainter painter = TextPainter(
          text: TextSpan(text: span.text, style: span.style),
          textDirection: TextDirection.ltr,
          textScaleFactor: 1.0,
        );
        painter.layout(maxWidth: maxWidth);
        totalContentHeight += painter.height;
        painter.dispose();
      }
    }

    double pageRatio = totalContentHeight / maxHeight;

    // Calculate character limits - BALANCED: İyi doluluk ama güvenli
    const double baseFontSize = 13.0;
    const int baseMinChars = 1100; // Orijinal: 800, Agresif: 1200
    const int baseMaxChars = 1400; // Orijinal: 1000, Agresif: 1600
    const double referenceArea = 350.0 * 600.0;

    final double currentArea = maxWidth * maxHeight;
    double screenCapacityFactor = (currentArea / referenceArea).clamp(0.8, 1.15);

    final currentFontSize = contentStyle.fontSize ?? baseFontSize;
    final fontScaleFactor = baseFontSize / currentFontSize;

    int minCharsPerPage = (baseMinChars * fontScaleFactor * screenCapacityFactor).round();
    int maxCharsPerPage = (baseMaxChars * fontScaleFactor * screenCapacityFactor).round();

    // Dengeli limitler
    if (maxCharsPerPage > 1600) maxCharsPerPage = 1600; // Orijinal: 1050, Agresif: 1800
    if (maxCharsPerPage < 700) maxCharsPerPage = 700; // Orijinal: 500, Agresif: 800
    // Güvenli doluluk payı (%97) - satır taşmasını azaltır
    maxCharsPerPage = (maxCharsPerPage * 0.97).floor();
    if (minCharsPerPage > maxCharsPerPage) minCharsPerPage = maxCharsPerPage - 80;

    return _PageMetrics(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      totalChars: totalChars,
      pageRatio: pageRatio,
      minCharsPerPage: minCharsPerPage,
      maxCharsPerPage: maxCharsPerPage,
    );
  }

  List<TextSpan> _distributeToPages(List<InlineSpan> flatSpans, _PageMetrics metrics) {
    List<int> spanCharCounts = flatSpans.map((span) {
      if (span is TextSpan && span.text != null) {
        return span.text!.length;
      }
      return 0;
    }).toList();

    List<List<InlineSpan>> allPages = [];
    List<InlineSpan> currentPageList = [];
    int currentPageChars = 0;

    int getRemainingChars(int fromIndex) {
      int remaining = 0;
      for (int j = fromIndex; j < flatSpans.length; j++) {
        remaining += spanCharCounts[j];
      }
      return remaining;
    }

    for (int i = 0; i < flatSpans.length; i++) {
      final span = flatSpans[i];
      final spanChars = spanCharCounts[i];

      // SUBCHAPTER kontrolü - semanticsLabel ile işaretli başlıklar
      bool isSubchapterHeading = false;
      if (span is TextSpan && span.semanticsLabel != null && span.semanticsLabel!.startsWith('SUBCHAPTER:')) {
        isSubchapterHeading = true;
      }

      // SUBCHAPTER BAŞLIKLARI için ÖZEL KURAL: Her zaman yeni sayfa başlat
      if (isSubchapterHeading && currentPageList.isNotEmpty) {
        // Subchapter başlığı tespit edildi - mevcut sayfayı bitir, yeni sayfa aç
        _detectSubchaptersInSpans(currentPageList, allPages.length);
        allPages.add(List.from(currentPageList));
        currentPageList.clear();
        currentPageChars = 0;
      }
      // Normal başlıklar (h1/h2/h3) için - sadece sayfa yeterince doluysa yeni sayfa aç
      else if (_isHeadingSpan(span) && currentPageList.isNotEmpty && currentPageChars > metrics.minCharsPerPage * 0.55) {
        _detectSubchaptersInSpans(currentPageList, allPages.length);
        allPages.add(List.from(currentPageList));
        currentPageList.clear();
        currentPageChars = 0;
      }

      if (currentPageChars + spanChars > metrics.maxCharsPerPage) {
        // Orphan prevention - AMA başlıklar için UYGULAMA
        // Başlık ise ve sayfa doluysa, yeni sayfaya taşıma
        int remainingAfterThis = getRemainingChars(i + 1);

        // BALANCED: Orphan prevention - kısa metinleri taşıma
        if (!_isHeadingSpan(span) && remainingAfterThis > 0 && remainingAfterThis < 150) {
          currentPageList.add(span);
          currentPageChars += spanChars;
          continue;
        }

        if (currentPageList.isNotEmpty && currentPageChars >= metrics.minCharsPerPage) {
          _detectSubchaptersInSpans(currentPageList, allPages.length);
          allPages.add(List.from(currentPageList));
          currentPageList.clear();
          currentPageChars = 0;
        }

        if (spanChars <= metrics.maxCharsPerPage) {
          currentPageList.add(span);
          currentPageChars += spanChars;
          continue;
        }

        // Split large text spans
        if (span is TextSpan && span.text != null) {
          _splitLargeTextSpan(
            span,
            currentPageList,
            currentPageChars,
            metrics,
            allPages,
          );
          currentPageList = [];
          currentPageChars = 0;
        } else {
          _handleLargeWidgetSpan(span, spanChars, currentPageList, currentPageChars, allPages);
          currentPageList = [];
          currentPageChars = 0;
        }
      } else {
        currentPageList.add(span);
        currentPageChars += spanChars;
      }
    }

    // Add remaining content
    if (currentPageList.isNotEmpty) {
      bool hasRealContent = currentPageList.any((s) {
        if (s is TextSpan && s.text != null) return s.text!.trim().isNotEmpty;
        if (s is WidgetSpan) return true;
        return false;
      });

      if (hasRealContent) {
        _detectSubchaptersInSpans(currentPageList, allPages.length);
        allPages.add(currentPageList);
      } else if (allPages.isNotEmpty) {
        allPages.last.addAll(currentPageList);
      }
    }

    // OVERFLOW KONTROLÜ: Taşan sayfaları otomatik düzelt
    allPages = _fixOverflowingPages(allPages, metrics);

    // SAYFA BİRLEŞTİRME: Düşük doluluklu sayfaları birleştir
    allPages = _mergeLowDensityPages(allPages, metrics);

    return allPages.map((pageSpans) => TextSpan(children: pageSpans)).toList();
  }

  bool _isHeadingSpan(InlineSpan span) {
    if (span is TextSpan) {
      final style = span.style;
      if (style != null) {
        final fontSize = style.fontSize ?? 0;
        final fontWeight = style.fontWeight;
        final baseFontSize = contentStyle.fontSize ?? 14;
        final text = span.text ?? '';
        final trimmedText = text.trim();

        final isBoldWeight = fontWeight == FontWeight.w500 || fontWeight == FontWeight.w600 || fontWeight == FontWeight.w700 || fontWeight == FontWeight.bold;

        return fontSize >= baseFontSize + 3 && isBoldWeight && trimmedText.isNotEmpty;
      }
    }
    return false;
  }

  void _splitLargeTextSpan(
    TextSpan span,
    List<InlineSpan> currentPageList,
    int currentPageChars,
    _PageMetrics metrics,
    List<List<InlineSpan>> allPages,
  ) {
    String remainingText = span.text!;
    TextStyle? style = span.style;
    List<InlineSpan> tempPageList = List.from(currentPageList);
    int tempPageChars = currentPageChars;

    while (remainingText.isNotEmpty) {
      int spaceLeft = metrics.maxCharsPerPage - tempPageChars;

      if (spaceLeft < 100 && tempPageList.isNotEmpty) {
        allPages.add(List.from(tempPageList));
        tempPageList.clear();
        tempPageChars = 0;
        spaceLeft = metrics.maxCharsPerPage;
      }

      if (remainingText.length <= spaceLeft) {
        tempPageList.add(TextSpan(text: remainingText, style: style));
        tempPageChars += remainingText.length;
        remainingText = '';
      } else {
        int splitIndex = remainingText.lastIndexOf(' ', spaceLeft);
        if (splitIndex == -1 || splitIndex < spaceLeft * 0.7) {
          splitIndex = spaceLeft;
        }

        String textPart = remainingText.substring(0, splitIndex);
        remainingText = remainingText.substring(splitIndex);
        if (remainingText.startsWith(' ')) {
          remainingText = remainingText.substring(1);
        }

        tempPageList.add(TextSpan(text: textPart, style: style));
        tempPageChars += textPart.length;

        allPages.add(List.from(tempPageList));
        tempPageList.clear();
        tempPageChars = 0;
      }
    }

    if (tempPageList.isNotEmpty) {
      currentPageList.clear();
      currentPageList.addAll(tempPageList);
    }
  }

  void _handleLargeWidgetSpan(
    InlineSpan span,
    int spanChars,
    List<InlineSpan> currentPageList,
    int currentPageChars,
    List<List<InlineSpan>> allPages,
  ) {
    if (currentPageList.isEmpty) {
      currentPageList.add(span);
      allPages.add(List.from(currentPageList));
      currentPageList.clear();
    } else {
      allPages.add(List.from(currentPageList));
      currentPageList.clear();
      currentPageList.add(span);
    }
  }

  /// Detect subchapters in a list of spans and record their page number
  void _detectSubchaptersInSpans(List<InlineSpan> spans, int pageIndex) {
    for (var span in spans) {
      if (span is TextSpan && span.semanticsLabel != null && span.semanticsLabel!.startsWith('SUBCHAPTER:')) {
        final subchapterTitle = span.semanticsLabel!.substring('SUBCHAPTER:'.length);
        if (!subchapterPageMap.containsKey(subchapterTitle)) {
          subchapterPageMap[subchapterTitle] = pageIndex;
        }
      }
    }
  }

  /// Taşan sayfaları tespit edip düzelt - son satırı sonraki sayfaya taşı
  List<List<InlineSpan>> _fixOverflowingPages(List<List<InlineSpan>> pages, _PageMetrics metrics) {
    List<List<InlineSpan>> fixedPages = [];

    for (int pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      List<InlineSpan> currentPage = List.from(pages[pageIdx]);

      // Sayfanın gerçek yüksekliğini ölç
      double actualHeight = _measurePageHeight(currentPage, metrics.maxWidth);

      // Eğer sayfa maxHeight'tan %92'den fazla doluysa, taşma riski var
      double fillRatio = actualHeight / metrics.maxHeight;

      if (fillRatio > 0.92 && currentPage.isNotEmpty) {
        // Son birkaç span'i bul ve sonraki sayfaya taşı
        List<InlineSpan> itemsToMove = [];
        int removeCount = 0;

        // Son text span'lerden 1-3 tanesini bul (yaklaşık 1 satır)
        for (int i = currentPage.length - 1; i >= 0 && removeCount < 3; i--) {
          if (currentPage[i] is TextSpan) {
            final textSpan = currentPage[i] as TextSpan;
            if (textSpan.text != null && textSpan.text!.trim().isNotEmpty) {
              itemsToMove.insert(0, currentPage[i]);
              removeCount++;

              // Yaklaşık 1 satır kadar metin taşındıysa dur
              int totalChars = itemsToMove.fold(0, (sum, span) {
                if (span is TextSpan && span.text != null) return sum + span.text!.length;
                return sum;
              });

              if (totalChars > 80) break; // ~1 satır
            }
          }
        }

        // Taşınacak item'ları kaldır
        for (var item in itemsToMove) {
          currentPage.remove(item);
        }

        // Düzeltilmiş sayfayı ekle
        fixedPages.add(currentPage);

        // Sonraki sayfaya taşınan item'ları ekle
        if (itemsToMove.isNotEmpty) {
          if (pageIdx + 1 < pages.length) {
            // Sonraki sayfa varsa, başına ekle
            pages[pageIdx + 1].insertAll(0, itemsToMove);
          } else {
            // Sonraki sayfa yoksa, yeni sayfa oluştur
            fixedPages.add(itemsToMove);
          }
        }
      } else {
        // Sayfa normal, olduğu gibi ekle
        fixedPages.add(currentPage);
      }
    }

    return fixedPages;
  }

  /// Bir sayfanın gerçek yüksekliğini ölç
  double _measurePageHeight(List<InlineSpan> spans, double maxWidth) {
    if (spans.isEmpty) return 0;

    try {
      TextPainter painter = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
        textScaleFactor: 1.0,
      );
      painter.layout(maxWidth: maxWidth);
      double height = painter.height;
      painter.dispose();
      return height;
    } catch (e) {
      // Hata durumunda tahmini yükseklik döndür
      return 0;
    }
  }

  /// Düşük doluluk oranlı ardışık sayfaları birleştir (Apple Books tarzı)
  List<List<InlineSpan>> _mergeLowDensityPages(List<List<InlineSpan>> pages, _PageMetrics metrics) {
    if (pages.length <= 1) return pages;

    print('\n🔄 ========== SAYFA BİRLEŞTİRME BAŞLADI ==========');
    print('📄 Toplam Sayfa: ${pages.length}');
    print('📊 Max Karakter/Sayfa: ${metrics.maxCharsPerPage}');

    List<List<InlineSpan>> mergedPages = [];
    int i = 0;
    int mergeCount = 0;

    while (i < pages.length) {
      List<InlineSpan> currentPage = List.from(pages[i]);

      // Sayfa doluluk oranını hesapla (yükseklik bazlı)
      int currentChars = _countCharsInSpans(currentPage);
      double currentHeight = _measurePageHeight(currentPage, metrics.maxWidth);
      double currentFill = metrics.maxHeight == 0 ? 0.0 : (currentHeight / metrics.maxHeight);

      // Sonraki sayfayı kontrol et
      if (i + 1 < pages.length) {
        List<InlineSpan> nextPage = pages[i + 1];
        int nextChars = _countCharsInSpans(nextPage);
        double nextHeight = _measurePageHeight(nextPage, metrics.maxWidth);
        double nextFill = metrics.maxHeight == 0 ? 0.0 : (nextHeight / metrics.maxHeight);
        int combinedChars = currentChars + nextChars;
        final combinedPage = <InlineSpan>[...currentPage, ...nextPage];
        double combinedHeight = _measurePageHeight(combinedPage, metrics.maxWidth);
        double combinedFill = metrics.maxHeight == 0 ? 0.0 : (combinedHeight / metrics.maxHeight);

        bool startsWithHeading = _startsWithHeading(nextPage);

        // Debug print
        print('\n📖 Sayfa ${i + 1} -> ${i + 2}:');
        print('   Sayfa ${i + 1}: ${(currentFill * 100).toStringAsFixed(1)}% ($currentChars kar)');
        print('   Sayfa ${i + 2}: ${(nextFill * 100).toStringAsFixed(1)}% ($nextChars kar)');
        print('   Birleşik: ${(combinedFill * 100).toStringAsFixed(1)}% ($combinedChars kar)');
        print('   Başlıkla başlıyor: $startsWithHeading');

        // BİRLEŞTİRME KURALLARI:
        // Öncelikli: İki sayfa da %60'ın altındaysa direkt birleştir
        // Normal: İki sayfa da %75'in altındaysa VE birleşince %97'nin altında kalacaksa
        bool isPriorityMerge = currentFill < 0.60 && nextFill < 0.60 && combinedFill < 0.97 && !startsWithHeading;

        bool rule1 = currentFill < 0.75;
        bool rule2 = nextFill < 0.75;
        bool rule3 = combinedFill < 0.97;
        bool rule4 = !startsWithHeading;

        print('   ✓ Kural 1 (<75%): ${rule1 ? "✅" : "❌"}');
        print('   ✓ Kural 2 (<75%): ${rule2 ? "✅" : "❌"}');
        print('   ✓ Kural 3 (<97%): ${rule3 ? "✅" : "❌"}');
        print('   ✓ Kural 4 (başlık yok): ${rule4 ? "✅" : "❌"}');

        bool canMerge = (isPriorityMerge || (rule1 && rule2 && rule3 && rule4));

        if (canMerge) {
          // Sayfaları birleştir
          print('   ✅ BİRLEŞTİRİLDİ! 🎉');
          currentPage.addAll(nextPage);
          mergedPages.add(currentPage);
          mergeCount++;
          i += 2; // İki sayfayı da atla
          continue;
        }

        // YENİ KURAL: Başlık yoksa, birleşik içerik %97'yi aşıyorsa yeniden dengele
        // (Apple Books tarzı: sayfa 1'i %97'ye tamamla, kalan sayfa 2'de kalsın)
        bool canRebalance = !startsWithHeading && combinedFill > 0.97;

        if (canRebalance) {
          print('   🔄 YENİDEN DENGELEME YAPILIYOR...');

          // Tüm içeriği birleştir
          List<InlineSpan> allContent = List.from(currentPage);
          allContent.addAll(nextPage);

          // İlk sayfayı %97'ye tamamla
          int targetCharsForFirstPage = (metrics.maxCharsPerPage * 0.97).round();

          // Sayfayı böl
          var rebalancedPages = _splitPageAtCharCount(allContent, targetCharsForFirstPage);

          if (rebalancedPages != null) {
            int newFirstChars = _countCharsInSpans(rebalancedPages['first']!);
            int newSecondChars = _countCharsInSpans(rebalancedPages['second']!);

            print('   ✅ DENGELEME BAŞARILI!');
            print('      Yeni Sayfa ${i + 1}: ${((newFirstChars / metrics.maxCharsPerPage) * 100).toStringAsFixed(1)}% ($newFirstChars kar)');
            print('      Yeni Sayfa ${i + 2}: ${((newSecondChars / metrics.maxCharsPerPage) * 100).toStringAsFixed(1)}% ($newSecondChars kar)');

            mergedPages.add(rebalancedPages['first']!);

            // Eğer ikinci kısım çok küçükse ve sonraki sayfa varsa, onu da birleştir
            if (newSecondChars < metrics.maxCharsPerPage * 0.3 && i + 2 < pages.length) {
              // Sonraki sayfayla birleştirmeyi dene
              List<InlineSpan> remainderPlusNext = List.from(rebalancedPages['second']!);
              remainderPlusNext.addAll(pages[i + 2]);

              int combinedRemainder = _countCharsInSpans(remainderPlusNext);
              if (combinedRemainder < metrics.maxCharsPerPage * 0.97) {
                mergedPages.add(remainderPlusNext);
                i += 3;
                mergeCount++;
                continue;
              }
            }

            mergedPages.add(rebalancedPages['second']!);
            mergeCount++;
            i += 2;
            continue;
          }
        }

        print('   ❌ Birleştirilmedi');
      }

      // Birleştirilmediyse normal ekle
      mergedPages.add(currentPage);
      i++;
    }

    print('\n🎯 SONUÇ:');
    print('   Önceki Sayfa Sayısı: ${pages.length}');
    print('   Yeni Sayfa Sayısı: ${mergedPages.length}');
    print('   Birleştirilen Çift: $mergeCount');

    // POST-PROCESSING: %97'den fazla dolu sayfaları düzelt
    print('\n🔧 POST-PROCESSING: Taşma kontrolü...');
    mergedPages = _fixOverfilledPages(mergedPages, metrics);
    // POST-PROCESSING: yükseklik taşmasını tekrar kontrol et
    mergedPages = _fixOverflowingPages(mergedPages, metrics);
    // POST-PROCESSING: sayfaları %97 yüksekliğe kadar doldur
    mergedPages = _compactPagesToTargetHeight(mergedPages, metrics, 0.97);
    // POST-PROCESSING: çift newline temizliği + log
    mergedPages = _sanitizeDoubleNewlinesInPages(mergedPages, 'merge-post');
    // POST-PROCESSING: sayfa sınırında \n çakışmasını temizle
    mergedPages = _trimPageBoundaryNewlines(mergedPages, 'merge-post');
    // POST-PROCESSING: sayfa içi span sınırlarında \n çakışmasını temizle
    mergedPages = _trimAdjacentSpanNewlines(mergedPages, 'merge-post');

    print('========== BİRLEŞTİRME BİTTİ ==========\n');

    return mergedPages;
  }

  /// %97'den fazla dolu sayfaları %97'ye düşür ve kalanı sonraki sayfaya aktar
  List<List<InlineSpan>> _fixOverfilledPages(List<List<InlineSpan>> pages, _PageMetrics metrics) {
    List<List<InlineSpan>> fixedPages = [];
    int maxChars = (metrics.maxCharsPerPage * 0.97).round();

    for (int i = 0; i < pages.length; i++) {
      List<InlineSpan> currentPage = pages[i];
      int currentChars = _countCharsInSpans(currentPage);
      double density = currentChars / metrics.maxCharsPerPage;

      // Eğer sayfa %97'den fazla doluysa
      if (density > 0.97) {
        print('   ⚠️ Sayfa ${i + 1}: ${(density * 100).toStringAsFixed(1)}% ($currentChars kar) - FAZLA DOLU!');

        // Kaç karakter taşırmalıyız?
        int charsToMove = currentChars - maxChars;

        if (charsToMove > 0 && charsToMove < currentChars * 0.5) {
          // Sayfayı iki parçaya böl
          var split = _splitPageAtCharCount(currentPage, maxChars);

          if (split != null) {
            int newFirstChars = _countCharsInSpans(split['first']!);
            int newSecondChars = _countCharsInSpans(split['second']!);

            print('      ✅ DÜZELTİLDİ:');
            print('         Sayfa ${i + 1}: ${((newFirstChars / metrics.maxCharsPerPage) * 100).toStringAsFixed(1)}% ($newFirstChars kar)');
            print('         Yeni Sayfa ${i + 2}: ${((newSecondChars / metrics.maxCharsPerPage) * 100).toStringAsFixed(1)}% ($newSecondChars kar)');

            fixedPages.add(split['first']!);

            // Eğer sonraki sayfa varsa, taşan kısmı onunla birleştir
            if (i + 1 < pages.length) {
              List<InlineSpan> nextPage = List.from(split['second']!);
              nextPage.addAll(pages[i + 1]);
              pages[i + 1] = nextPage;
            } else {
              // Sonraki sayfa yoksa, yeni sayfa oluştur
              fixedPages.add(split['second']!);
            }
            continue;
          }
        }
      }

      fixedPages.add(currentPage);
    }

    return fixedPages;
  }

  /// Sayfaları hedef doluluğa (%97) kadar doldurmak için içerik taşır
  List<List<InlineSpan>> _compactPagesToTargetHeight(List<List<InlineSpan>> pages, _PageMetrics metrics, double targetFill) {
    if (pages.length <= 1) return pages;

    final maxWidth = metrics.maxWidth;
    final targetHeight = metrics.maxHeight * targetFill;

    int i = 0;
    while (i < pages.length - 1) {
      List<InlineSpan> currentPage = List.from(pages[i]);
      List<InlineSpan> nextPage = List.from(pages[i + 1]);

      if (_startsWithHeading(nextPage)) {
        i++;
        continue;
      }

      double currentHeight = _measurePageHeight(currentPage, maxWidth);
      if (currentHeight >= targetHeight) {
        i++;
        continue;
      }

      bool movedAny = false;
      while (nextPage.isNotEmpty) {
        final span = nextPage.first;
        final adjustedSpan = _adjustLeadingWhitespaceIfNeeded(currentPage, span);
        final tentative = List<InlineSpan>.from(currentPage)..add(adjustedSpan);
        double tentativeHeight = _measurePageHeight(tentative, maxWidth);

        if (tentativeHeight <= targetHeight) {
          currentPage.add(adjustedSpan);
          nextPage.removeAt(0);
          movedAny = true;
          currentHeight = tentativeHeight;
          if (currentHeight >= targetHeight) break;
          continue;
        }

        if (adjustedSpan is TextSpan && adjustedSpan.text != null) {
          final split = _splitTextSpanToFitHeight(adjustedSpan, currentPage, targetHeight, maxWidth);
          if (split != null) {
            if (split['first'] != null && (split['first'] as TextSpan).text!.trim().isNotEmpty) {
              currentPage.add(split['first']!);
              movedAny = true;
            }
            if (split['second'] != null && (split['second'] as TextSpan).text!.trim().isNotEmpty) {
              nextPage[0] = split['second']!;
            } else {
              nextPage.removeAt(0);
            }
          }
        }
        break;
      }

      pages[i] = currentPage;
      if (nextPage.isEmpty) {
        pages.removeAt(i + 1);
      } else {
        pages[i + 1] = nextPage;
      }

      if (!movedAny) {
        i++;
      }
    }

    // Son aşama: çift newline temizliği + log
    pages = _sanitizeDoubleNewlinesInPages(pages, 'compact');
    // Son aşama: sayfa sınırında \n çakışmasını temizle
    pages = _trimPageBoundaryNewlines(pages, 'compact');
    // Son aşama: sayfa içi span sınırlarında \n çakışmasını temizle
    pages = _trimAdjacentSpanNewlines(pages, 'compact');
    return pages;
  }

  /// Aynı sayfa içindeki span sınırlarında \n çakışmasını temizle
  List<List<InlineSpan>> _trimAdjacentSpanNewlines(List<List<InlineSpan>> pages, String stage) {
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final spans = pages[pageIndex];
      int i = 0;
      while (i < spans.length - 1) {
        final current = spans[i];
        final next = spans[i + 1];

        if (current is TextSpan && next is TextSpan) {
          final currentText = current.text ?? '';
          final nextText = next.text ?? '';

          if (currentText.endsWith('\n') && nextText.startsWith('\n')) {
            final cleanedNext = nextText.replaceFirst(RegExp(r'^\n+\s*'), '');
            if (cleanedNext.isEmpty) {
              spans.removeAt(i + 1);
              print('   🧹 Span sınırı \n kaldırıldı | stage: $stage | sayfa: ${pageIndex + 1} | span: ${i + 1}');
              continue;
            }
            if (cleanedNext != nextText) {
              spans[i + 1] = TextSpan(
                text: cleanedNext,
                style: next.style,
                semanticsLabel: next.semanticsLabel,
              );
              print('   🧹 Span sınırı \n temizlendi | stage: $stage | sayfa: ${pageIndex + 1} | span: ${i + 1}');
            }
          }
        }

        i++;
      }
    }
    return pages;
  }

  /// Sayfa sınırında biri \n ile bitiyor diğeri \n ile başlıyorsa, birini temizle
  List<List<InlineSpan>> _trimPageBoundaryNewlines(List<List<InlineSpan>> pages, String stage) {
    if (pages.length <= 1) return pages;

    for (int pageIndex = 0; pageIndex < pages.length - 1; pageIndex++) {
      final currentPage = pages[pageIndex];
      final nextPage = pages[pageIndex + 1];

      final lastTextIndex = _findLastTextSpanIndex(currentPage);
      final firstTextIndex = _findFirstTextSpanIndex(nextPage);

      if (lastTextIndex == -1 || firstTextIndex == -1) continue;

      final lastSpan = currentPage[lastTextIndex] as TextSpan;
      final firstSpan = nextPage[firstTextIndex] as TextSpan;

      final lastText = lastSpan.text ?? '';
      final firstText = firstSpan.text ?? '';

      const targetSnippet = 'Но это было почти два года назад';
      final lastPreview = lastText.replaceAll('\n', '\\n');
      final firstPreview = firstText.replaceAll('\n', '\\n');
      final boundaryHasDoubleNl = lastText.endsWith('\n') && firstText.startsWith('\n');
      final boundaryHasTarget = lastText.contains(targetSnippet) || firstText.contains(targetSnippet);

      if (boundaryHasDoubleNl || boundaryHasTarget) {
        print('   🧭 BOUNDARY DEBUG | stage: $stage | sayfa: ${pageIndex + 1} -> ${pageIndex + 2}');
        print('      🔚 last:  ${lastPreview.length > 200 ? lastPreview.substring(lastPreview.length - 200) : lastPreview}');
        print('      🔜 first: ${firstPreview.length > 200 ? firstPreview.substring(0, 200) : firstPreview}');
      }

      // 1) Eğer iki sayfa sınırında \n çakışıyorsa, sonraki sayfanın başındaki \n'i kaldır
      if (lastText.endsWith('\n') && firstText.startsWith('\n')) {
        final cleanedFirst = firstText.replaceFirst(RegExp(r'^\n+'), '');
        if (cleanedFirst != firstText) {
          nextPage[firstTextIndex] = TextSpan(
            text: cleanedFirst,
            style: firstSpan.style,
            semanticsLabel: firstSpan.semanticsLabel,
          );
        }
      }

      // 2) Eğer sayfa \n ile bitiyorsa ve sonraki sayfa gerçek metinle başlıyorsa, sonda tek \n kaldır
      if (lastText.endsWith('\n') && firstText.trimLeft().isNotEmpty) {
        final cleanedLast = lastText.replaceFirst(RegExp(r'\n+$'), '');
        if (cleanedLast != lastText) {
          currentPage[lastTextIndex] = TextSpan(
            text: cleanedLast,
            style: lastSpan.style,
            semanticsLabel: lastSpan.semanticsLabel,
          );
        }
      }
    }

    return pages;
  }

  int _findLastTextSpanIndex(List<InlineSpan> spans) {
    for (int i = spans.length - 1; i >= 0; i--) {
      final span = spans[i];
      if (span is TextSpan && span.text != null && span.text!.isNotEmpty) {
        return i;
      }
    }
    return -1;
  }

  int _findFirstTextSpanIndex(List<InlineSpan> spans) {
    for (int i = 0; i < spans.length; i++) {
      final span = spans[i];
      if (span is TextSpan && span.text != null && span.text!.isNotEmpty) {
        return i;
      }
    }
    return -1;
  }

  /// Birleşen sayfalarda oluşan çift newline'ları temizle ve logla
  List<List<InlineSpan>> _sanitizeDoubleNewlinesInPages(List<List<InlineSpan>> pages, String stage) {
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final spans = pages[pageIndex];
      for (int i = 0; i < spans.length; i++) {
        final span = spans[i];
        if (span is TextSpan && span.text != null && span.text!.contains('\n\n')) {
          final original = span.text!;
          final cleaned = original.replaceAll(RegExp(r'\n{2,}'), '\n');
          if (cleaned != original) {
            final preview = original.replaceAll('\n', '\\n');
            print('   🧹 Çift newline temizlendi | stage: $stage | sayfa: ${pageIndex + 1} | span: ${preview.length > 80 ? preview.substring(0, 80) : preview}');
            spans[i] = TextSpan(
              text: cleaned,
              style: span.style,
              semanticsLabel: span.semanticsLabel,
            );
          }
        }
      }
    }
    return pages;
  }

  /// Metni hedef yüksekliğe sığacak şekilde böler
  Map<String, TextSpan?>? _splitTextSpanToFitHeight(
    TextSpan span,
    List<InlineSpan> currentPage,
    double targetHeight,
    double maxWidth,
  ) {
    final text = span.text;
    if (text == null || text.trim().isEmpty) return null;

    final tokens = RegExp(r'\s+|\S+').allMatches(text).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return null;

    int low = 0;
    int high = tokens.length;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final prefix = tokens.take(mid).join();
      final candidate = List<InlineSpan>.from(currentPage)..add(TextSpan(text: prefix, style: span.style, semanticsLabel: span.semanticsLabel));
      final height = _measurePageHeight(candidate, maxWidth);
      if (height <= targetHeight) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    if (low == 0) return null;

    final firstText = tokens.take(low).join();
    final secondText = _normalizeLeadingWhitespace(tokens.skip(low).join(), true);

    return {
      'first': TextSpan(text: firstText, style: span.style, semanticsLabel: span.semanticsLabel),
      'second': secondText.trim().isEmpty ? null : TextSpan(text: secondText, style: span.style),
    };
  }

  bool _endsWithLineBreak(List<InlineSpan> spans) {
    for (int i = spans.length - 1; i >= 0; i--) {
      final span = spans[i];
      if (span is TextSpan && span.text != null && span.text!.isNotEmpty) {
        return RegExp(r'\n\s*$').hasMatch(span.text!);
      }
    }
    return false;
  }

  String _normalizeLeadingWhitespace(String text, bool previousEndsWithLineBreak) {
    if (text.isEmpty) return text;

    final originalText = text;
    int newlineCount = 0;
    for (int i = 0; i < text.length && text[i] == '\n'; i++) {
      newlineCount++;
    }

    // SERT ÇÖZÜM: Birleştirmede çift newline'ı tek newline'a düşür
    if (previousEndsWithLineBreak) {
      // Önceki parça zaten \n ile bitiyorsa, baştaki TÜM newline'ları kaldır
      text = text.replaceFirst(RegExp(r'^\n+'), '');
      // Sonra baştaki boşlukları da kırp
      text = text.replaceFirst(RegExp(r'^[ \t]+'), '');
    } else {
      // Önceki parça \n ile bitmiyorsa, çoklu \n'leri tek \n'e düşür
      text = text.replaceFirst(RegExp(r'^\n+'), '\n');
    }

    if (originalText != text && newlineCount >= 2) {
      print(
          '   🔧 NORMALIZE: "${originalText.substring(0, originalText.length > 20 ? 20 : originalText.length).replaceAll('\n', '\\n')}..." -> "${text.substring(0, text.length > 20 ? 20 : text.length).replaceAll('\n', '\\n')}..." (prevBreak: $previousEndsWithLineBreak, newlines: $newlineCount)');
    }

    return text;
  }

  InlineSpan _adjustLeadingWhitespaceIfNeeded(List<InlineSpan> currentPage, InlineSpan span) {
    if (span is! TextSpan || span.text == null) return span;
    final prevEndsWithBreak = _endsWithLineBreak(currentPage);
    final normalized = _normalizeLeadingWhitespace(span.text!, prevEndsWithBreak);
    if (normalized == span.text) return span;
    return TextSpan(text: normalized, style: span.style, semanticsLabel: span.semanticsLabel);
  }

  /// Sayfayı belirli karakter sayısında böl
  Map<String, List<InlineSpan>>? _splitPageAtCharCount(List<InlineSpan> page, int maxChars) {
    List<InlineSpan> firstPart = [];
    List<InlineSpan> secondPart = [];

    int charCount = 0;

    for (var span in page) {
      if (span is TextSpan && span.text != null) {
        int spanChars = span.text!.length;

        if (charCount + spanChars <= maxChars) {
          // Tamamını ilk parçaya ekle
          firstPart.add(span);
          charCount += spanChars;
        } else if (charCount < maxChars) {
          // Bu span'i bölmemiz gerekiyor
          int remainingChars = maxChars - charCount;
          String text = span.text!;

          // Kelime sınırında böl
          int splitIndex = remainingChars;
          int lastSpace = text.lastIndexOf(' ', splitIndex);
          if (lastSpace > splitIndex * 0.7 && lastSpace > 0) {
            splitIndex = lastSpace + 1;
          }

          String firstText = text.substring(0, splitIndex);
          String secondText = text.substring(splitIndex);

          if (firstText.isNotEmpty) {
            firstPart.add(TextSpan(
              text: firstText,
              style: span.style,
              semanticsLabel: span.semanticsLabel,
            ));
          }

          if (secondText.isNotEmpty) {
            secondPart.add(TextSpan(
              text: secondText,
              style: span.style,
            ));
          }

          charCount = maxChars;
        } else {
          // Hedef doldu, kalanları ikinci parçaya ekle
          secondPart.add(span);
        }
      } else {
        // Widget span - akıllı yerleştir
        if (charCount < maxChars * 0.9) {
          firstPart.add(span);
        } else {
          secondPart.add(span);
        }
      }
    }

    if (firstPart.isEmpty || secondPart.isEmpty) {
      return null;
    }

    return {
      'first': firstPart,
      'second': secondPart,
    };
  }

  /// Span listesindeki toplam karakter sayısını say
  int _countCharsInSpans(List<InlineSpan> spans) {
    int total = 0;
    for (var span in spans) {
      if (span is TextSpan && span.text != null) {
        total += span.text!.length;
      }
    }
    return total;
  }

  /// Sayfa başlıkla başlıyor mu kontrol et
  bool _startsWithHeading(List<InlineSpan> spans) {
    if (spans.isEmpty) return false;

    // İlk birkaç span'i kontrol et
    for (int i = 0; i < spans.length && i < 3; i++) {
      final span = spans[i];

      // Subchapter başlığı kontrolü
      if (span is TextSpan && span.semanticsLabel != null && span.semanticsLabel!.startsWith('SUBCHAPTER:')) {
        return true;
      }

      // Normal başlık kontrolü
      if (_isHeadingSpan(span)) {
        return true;
      }

      // Eğer gerçek metin bulunduysa (boşluk değilse), döngüyü kır
      if (span is TextSpan && span.text != null && span.text!.trim().isNotEmpty) {
        break;
      }
    }

    return false;
  }
}

class _PageMetrics {
  final double maxWidth;
  final double maxHeight;
  final int totalChars;
  final double pageRatio;
  final int minCharsPerPage;
  final int maxCharsPerPage;

  _PageMetrics({
    required this.maxWidth,
    required this.maxHeight,
    required this.totalChars,
    required this.pageRatio,
    required this.minCharsPerPage,
    required this.maxCharsPerPage,
  });
}
