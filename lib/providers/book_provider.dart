import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../services/api_service.dart';

class BookProvider extends ChangeNotifier {
  List<BookModel> _books = [];
  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _errorMessage;

  List<BookModel> get books => _books;
  bool get isLoading => _isLoading;
  bool get isUploadingImage => _isUploadingImage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchBooks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _books = await ApiService.getBooks();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadImage(Uint8List bytes, String filename, {String type = 'cover'}) async {
    _isUploadingImage = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.uploadBookImage(bytes: bytes, filename: filename, type: type);
      return res['url']?.toString();
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isUploadingImage = false;
      notifyListeners();
    }
  }

  Future<bool> createBook(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final book = await ApiService.createBook(data);
      _books.insert(0, book);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateBook(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await ApiService.updateBook(id, data);
      final index = _books.indexWhere((b) => b.id == id);
      if (index != -1) {
        _books[index] = updated;
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteBook(int id) async {
    try {
      await ApiService.deleteBook(id);
      _books.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
