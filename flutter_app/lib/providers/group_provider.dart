import 'package:flutter/material.dart';

import '../models/group.dart';
import '../services/group_service.dart';

class GroupProvider with ChangeNotifier {
  final GroupService _groupService = GroupService();

  List<Group> _groups = [];
  bool _isLoading = false;
  String? _error;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _groups = await _groupService.getGroups();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGroup({
    required String name,
    required List<String> memberIds,
    String description = '',
  }) async {
    final result = await _groupService.createGroup(
      name: name,
      memberIds: memberIds,
      description: description,
    );

    if (result['success'] == true) {
      _groups.insert(0, result['group'] as Group);
      notifyListeners();
      return true;
    }

    _error = result['error'] as String? ?? 'Failed to create group';
    notifyListeners();
    return false;
  }

  Future<bool> addMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    final result = await _groupService.addMembers(groupId: groupId, memberIds: memberIds);
    if (result['success'] == true) {
      _upsertGroup(result['group'] as Group);
      return true;
    }
    _error = result['error'] as String? ?? 'Failed to add members';
    notifyListeners();
    return false;
  }

  Future<bool> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    final result = await _groupService.removeMember(groupId: groupId, memberId: memberId);
    if (result['success'] == true) {
      if (result['deleted'] == true) {
        _groups.removeWhere((group) => group.id == groupId);
        notifyListeners();
      } else if (result['group'] is Group) {
        _upsertGroup(result['group'] as Group);
      }
      return true;
    }
    _error = result['error'] as String? ?? 'Failed to remove member';
    notifyListeners();
    return false;
  }

  Future<bool> promoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final result = await _groupService.promoteAdmin(groupId: groupId, memberId: memberId);
    if (result['success'] == true) {
      _upsertGroup(result['group'] as Group);
      return true;
    }
    _error = result['error'] as String? ?? 'Failed to promote admin';
    notifyListeners();
    return false;
  }

  Future<bool> demoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final result = await _groupService.demoteAdmin(groupId: groupId, memberId: memberId);
    if (result['success'] == true) {
      _upsertGroup(result['group'] as Group);
      return true;
    }
    _error = result['error'] as String? ?? 'Failed to demote admin';
    notifyListeners();
    return false;
  }

  void _upsertGroup(Group updated) {
    final index = _groups.indexWhere((group) => group.id == updated.id);
    if (index >= 0) {
      _groups[index] = updated;
    } else {
      _groups.insert(0, updated);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
