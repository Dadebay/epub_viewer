import 'package:cosmos_epub/page_flip/page_flip_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Controller for handling page navigation and state
class PagingTextHandler extends GetxController {
  PagingTextHandler({required this.paginate, required this.bookId}) {
    currentPage = (_box.read<int>('currentPage_$bookId') ?? 0).obs;
    totalPages = (_box.read<int>('totalPages_$bookId') ?? 0).obs;

    ever(currentPage, (_) => _box.write('currentPage_$bookId', currentPage.value));
    ever(totalPages, (_) => _box.write('totalPages_$bookId', totalPages.value));
  }

  final String bookId;
  late final RxInt currentPage;
  final Function paginate;
  late final RxInt totalPages;

  final _box = GetStorage();
  GlobalKey<PageFlipWidgetState>? _pageFlipController;

  void setPageFlipController(GlobalKey<PageFlipWidgetState> controller) {
    _pageFlipController = controller;
  }

  Future<void> goToNextPage() async {
    final state = _pageFlipController?.currentState;
    if (state == null) return;

    final currentPageNum = state.pageNumber;
    final totalPages = state.pages.length;

    if (currentPageNum < totalPages - 1) {
      final targetPage = currentPageNum + 1;
      await state.goToPage(targetPage);
      state.widget.onPageFlip(targetPage);
    }
  }

  Future<void> goToPreviousPage() async {
    final state = _pageFlipController?.currentState;
    if (state == null) return;

    final currentPageNum = state.pageNumber;

    if (currentPageNum > 0) {
      final targetPage = currentPageNum - 1;
      await state.goToPage(targetPage);
      state.widget.onPageFlip(targetPage);
    }
  }

  Future<bool> goToPage(int pageIndex) async {
    final state = _pageFlipController?.currentState;
    if (state == null) return false;

    final totalPagesCount = state.pages.length;

    if (pageIndex >= 0 && pageIndex < totalPagesCount) {
      await state.goToPage(pageIndex);
      state.widget.onPageFlip(pageIndex);
      return true;
    } else {
      return false;
    }
  }
}
