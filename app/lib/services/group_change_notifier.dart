import 'package:flutter/foundation.dart';


/// Singleton ChangeNotifier that broadcasts whenever the user's group
/// membership changes (create, join, leave, delete).
///
/// Any screen that needs to react to group changes should listen to this
/// notifier instead of relying on initState() alone.
class GroupChangeNotifier extends ChangeNotifier {
  static final GroupChangeNotifier _instance = GroupChangeNotifier._();
  static GroupChangeNotifier get instance => _instance;

  GroupChangeNotifier._();

  /// The group_id that should become active after the next groups refresh.
  /// Set by acceptInvitation flow so LiveMapScreen can auto-select the joined group.
  String? _pendingActiveGroupId;
  String? get pendingActiveGroupId => _pendingActiveGroupId;

  /// Clears the pending active group id after it has been consumed.
  void consumePendingActiveGroupId() {
    _pendingActiveGroupId = null;
  }

  /// Call this after any operation that changes the user's group list:
  /// createGroup, joinGroup, leaveGroup, deleteGroup, acceptInvitation.
  void notifyGroupsChanged() {
    notifyListeners();
  }

  /// Call this after accepting an invitation.
  /// [groupId] will be set as the active group when LiveMapScreen refreshes.
  void notifyGroupsChangedWithActiveGroup(String? groupId) {
    _pendingActiveGroupId = groupId;
    notifyListeners();
  }
}
