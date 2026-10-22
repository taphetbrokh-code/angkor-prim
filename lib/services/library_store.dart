import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Local library: history, liked videos, watch later, subscriptions,
/// search history and settings. Everything is stored on the phone.
class LibraryStore extends ChangeNotifier {
  LibraryStore._();
  static final LibraryStore instance = LibraryStore._();

  late SharedPreferences _p;

  List<VItem> history = [];
  List<VItem> liked = [];
  List<VItem> watchLater = [];
  List<ChannelRef> subs = [];
  List<String> searches = [];

  bool autoplay = true;
  int maxHeight = 720;
  bool audioOnly = false;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    history = _loadV('history');
    liked = _loadV('liked');
    watchLater = _loadV('later');
    subs = (_p.getStringList('subs') ?? [])
        .map((s) => ChannelRef.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    searches = _p.getStringList('searches') ?? [];
    autoplay = _p.getBool('autoplay') ?? true;
    maxHeight = _p.getInt('maxHeight') ?? 720;
    audioOnly = _p.getBool('audioOnly') ?? false;
  }

  List<VItem> _loadV(String key) {
    try {
      return (_p.getStringList(key) ?? [])
          .map((s) => VItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _saveV(String key, List<VItem> list) {
    _p.setStringList(key, list.map((v) => jsonEncode(v.toJson())).toList());
  }

  // ---- history ----
  void addHistory(VItem v) {
    history.removeWhere((e) => e.id == v.id);
    history.insert(0, v);
    if (history.length > 300) history = history.sublist(0, 300);
    _saveV('history', history);
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _saveV('history', history);
    notifyListeners();
  }

  void removeHistory(VItem v) {
    history.removeWhere((e) => e.id == v.id);
    _saveV('history', history);
    notifyListeners();
  }

  // ---- liked ----
  bool isLiked(String id) => liked.any((e) => e.id == id);
  void toggleLike(VItem v) {
    if (isLiked(v.id)) {
      liked.removeWhere((e) => e.id == v.id);
    } else {
      liked.insert(0, v);
    }
    _saveV('liked', liked);
    notifyListeners();
  }

  // ---- watch later ----
  bool isSaved(String id) => watchLater.any((e) => e.id == id);
  void toggleSave(VItem v) {
    if (isSaved(v.id)) {
      watchLater.removeWhere((e) => e.id == v.id);
    } else {
      watchLater.insert(0, v);
    }
    _saveV('later', watchLater);
    notifyListeners();
  }

  // ---- subscriptions ----
  bool isSub(String channelId) => subs.any((e) => e.id == channelId);
  void toggleSub(ChannelRef c) {
    if (isSub(c.id)) {
      subs.removeWhere((e) => e.id == c.id);
    } else {
      subs.insert(0, c);
    }
    _p.setStringList('subs', subs.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  // ---- search history ----
  void addSearch(String q) {
    q = q.trim();
    if (q.isEmpty) return;
    searches.remove(q);
    searches.insert(0, q);
    if (searches.length > 30) searches = searches.sublist(0, 30);
    _p.setStringList('searches', searches);
  }

  void removeSearch(String q) {
    searches.remove(q);
    _p.setStringList('searches', searches);
    notifyListeners();
  }

  // ---- settings ----
  void setAutoplay(bool v) {
    autoplay = v;
    _p.setBool('autoplay', v);
    notifyListeners();
  }

  void setMaxHeight(int v) {
    maxHeight = v;
    _p.setInt('maxHeight', v);
    notifyListeners();
  }

  void setAudioOnly(bool v) {
    audioOnly = v;
    _p.setBool('audioOnly', v);
    notifyListeners();
  }
}
