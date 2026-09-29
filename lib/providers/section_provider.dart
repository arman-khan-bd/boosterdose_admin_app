import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/section_model.dart';
import '../services/api_service.dart';

class SectionProvider extends ChangeNotifier {
  List<SectionModel> _sections = [];
  List<Map<String, dynamic>> _presetImages = [];
  List<dynamic> _books = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SectionModel> get sections => _sections;
  List<Map<String, dynamic>> get presetImages => _presetImages;
  List<dynamic> get books => _books;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SectionModel? get navbarSection {
    try {
      return _sections.firstWhere((s) => s.sectionKey == 'navbar');
    } catch (_) {
      return null;
    }
  }

  SectionModel? get noticeBarSection {
    try {
      return _sections.firstWhere((s) => s.sectionKey == 'notice_bar');
    } catch (_) {
      return null;
    }
  }

  SectionModel? get heroSection {
    try {
      return _sections.firstWhere((s) => s.sectionKey == 'hero');
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchSections() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.getSectionsData();
      _sections = res['sections'] as List<SectionModel>;
      _presetImages = res['presetImages'] as List<Map<String, dynamic>>;
      _books = res['books'] as List<dynamic>;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleSection(int id) async {
    try {
      final newStatus = await ApiService.toggleSection(id);
      final index = _sections.indexWhere((s) => s.id == id);
      if (index != -1) {
        final old = _sections[index];
        _sections[index] = old.copyWith(isActive: newStatus);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _sections.removeAt(oldIndex);
    _sections.insert(newIndex, item);
    notifyListeners();

    final orderList = <Map<String, dynamic>>[];
    for (int i = 0; i < _sections.length; i++) {
      _sections[i] = _sections[i].copyWith(sortOrder: i + 1);
      orderList.add({
        'id': _sections[i].id,
        'sort_order': i + 1,
      });
    }

    try {
      await ApiService.reorderSections(orderList);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> updateSection(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await ApiService.updateSection(id, data);
      final index = _sections.indexWhere((s) => s.id == id);
      if (index != -1) {
        _sections[index] = updated;
      }
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadSectionImage(
    int id,
    Uint8List bytes,
    String filename, {
    String targetField = 'image_url',
  }) async {
    try {
      final res = await ApiService.uploadSectionImage(
        id,
        bytes: bytes,
        filename: filename,
        targetField: targetField,
      );
      if (res['section'] != null) {
        final updated = SectionModel.fromJson(res['section']);
        final index = _sections.indexWhere((s) => s.id == id);
        if (index != -1) {
          _sections[index] = updated;
          notifyListeners();
        }
      }
      return res['url'] ?? res['image_url'];
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> uploadMedia(Uint8List bytes, String filename) async {
    try {
      return await ApiService.uploadSectionMedia(
        bytes: bytes,
        filename: filename,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> resetSectionImage(int id, {String targetField = 'image_url'}) async {
    try {
      final updated = await ApiService.resetSectionImage(id, targetField: targetField);
      final index = _sections.indexWhere((s) => s.id == id);
      if (index != -1) {
        _sections[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveHero(Map<String, dynamic> heroData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await ApiService.saveHeroSection(heroData);
      final index = _sections.indexWhere((s) => s.sectionKey == 'hero');
      if (index != -1) {
        _sections[index] = updated;
      }
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
