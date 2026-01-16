

# ElKitap EPUB Reader 💫

**ElKitap EPUB Reader** is a Flutter package that allows users to open and read **EPUB** files easily. It provides features like opening **EPUB** files from ***assets*** or ***local path***, changing themes, adjusting font styles and sizes, accessing chapter contents, and more.
The reader is **responsive**, enabling its use with both normal-sized smartphones and tablets.

## Features

* Open EPUB files from assets or local path.
* **RTL (Right-to-Left) language support** for Arabic, Persian, Hebrew, Urdu, and other RTL languages
* **Automatic text direction detection** with proper alignment and navigation
* Change themes with 5 options: Grey, Purple, White, Black, and Pink
* Customize font style and size
* Access table of contents and navigate to specific chapters
* Display current chapter name at the bottom of the screen
* Previous and next buttons to switch between chapters (RTL-aware)
* Adjust screen brightness
* Save book reading progress
* Nice page flip animation while reading
* **Mixed content support** (LTR + RTL text in the same document)
* ...and feel free to ask for new features or open an issue.

## Getting Started

In your Flutter project, add the dependency:

```yaml
dependencies:
  elkitap_epub_reader: ^x.y.z
```

Run the command:

```bash
flutter pub get
```

For more information, check out the [Flutter documentation](https://flutter.dev/).

## Usage Example

Import the package in your Dart code:

```dart
import 'package:elkitap_epub_reader/elkitap_epub_reader.dart';
```

First, you need to `initialize` the database before using any other method.
It’s best to do this early, preferably in your `main.dart` file.

There are various methods to control book progress as well:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initializer and methods return a bool
  var _initialized = await ElKitapEpubReader.initialize();

  if (_initialized) {
    BookProgressModel bookProgress = ElKitapEpubReader.getBookProgress('bookId');
    await ElKitapEpubReader.setCurrentPageIndex('bookId', 1);
    await ElKitapEpubReader.setCurrentChapterIndex('bookId', 2);
    await ElKitapEpubReader.deleteBookProgress('bookId');
    await ElKitapEpubReader.deleteAllBooksProgress();
  }

  runApp(MyApp());
}
```

To open an EPUB file from the assets, use the `openAssetBook` method:

```dart
await ElKitapEpubReader.openAssetBook(
  assetPath: 'assets/book.epub',
  context: context,
  // Book ID is required to save progress for each book
  bookId: '3',
  // Callbacks are optional
  onPageFlip: (int currentPage, int totalPages) {
    print(currentPage);
  },
  onLastPage: (int lastPageIndex) {
    print('We arrived at the last page');
  },
);
```

To open an EPUB file from local storage, use the `openLocalBook` method:

```dart
await ElKitapEpubReader.openLocalBook(
  localPath: book.path,
  context: context,
  // Book ID is required to save progress for each book
  bookId: '3',
  // Callbacks are optional
  onPageFlip: (int currentPage, int totalPages) {
    print(currentPage);
  },
  onLastPage: (int lastPageIndex) {
    print('We arrived at the last page');
  },
);
```

You can also use `ElKitapEpubReader.openURLBook` and `ElKitapEpubReader.openFileBook` for your convenience.

For clearing theme cache, use this method:

```dart
await ElKitapEpubReader.clearThemeCache();
```

---

## RTL Language Support 🌍

ElKitap EPUB Reader includes comprehensive support for Right-to-Left (RTL) languages such as Arabic, Persian (Farsi), Hebrew, Urdu, and more.

### Features:

* **Automatic Detection**: The library automatically detects RTL content and applies the correct text direction
* **Smart Navigation**: Navigation buttons automatically reverse for RTL content (left arrow becomes “next” for RTL)
* **Proper Alignment**: Text is properly aligned based on language direction
* **Chapter List Support**: Table of contents supports RTL layout with proper indentation
* **Mixed Content**: Handles documents with both LTR and RTL text seamlessly

### Supported Languages:

* Arabic (العربية)
* Persian/Farsi (فارسی)
* Hebrew (עברית)
* Urdu (اردو)
* Pashto (پښتو)
* Sindhi (سنڌي)
* Kurdish (کوردی)
* Dhivehi/Maldivian (ދިވެހި)
* Yiddish (ייִדיש)

### Usage:

No additional configuration is required!
Simply open your RTL EPUB file as usual:

```dart
await ElKitapEpubReader.openAssetBook(
  assetPath: 'assets/arabic_book.epub',
  context: context,
  bookId: 'arabic_book_1',
  onPageFlip: (currentPage, totalPages) {
    print('Page: $currentPage of $totalPages');
  },
);
```

The library will automatically:

1. Detect the text direction from the content
2. Apply proper RTL layout and navigation
3. Handle mixed LTR/RTL content appropriately

