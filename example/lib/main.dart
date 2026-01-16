import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:cosmos_epub/helpers/progress_singleton.dart';
import 'package:cosmos_epub/models/book_progress_model.dart';
import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Isar veritabanını initialize et
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [BookProgressModelSchema],
    directory: dir.path,
  );

  // Global bookProgress'i initialize et
  bookProgress = BookProgressSingleton(isar: isar);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'EPUB Reader Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'EPUB Reader Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;

  void _openEpubBook() async {
    try {
      // Dosya seçici aç
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
        });

        // Dosyayı oku
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();

        // EPUB'u parse et
        final epubBook = await EpubReader.readBook(bytes);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Dosya adını al
        final fileName = result.files.single.name.replaceAll('.epub', '');

        // Kitabı aç
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShowEpub(
              epubBook: epubBook,
              bookId: fileName,
              accentColor: Colors.deepPurple,
              imageUrl: 'https://via.placeholder.com/300x400',
              chapterListTitle: 'Bölümler',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.book,
              size: 100,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 20),
            const Text(
              'EPUB Kitap Okuyucu Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cihazınızdan EPUB dosyası seçin',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _openEpubBook,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('EPUB Dosyası Seç'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
