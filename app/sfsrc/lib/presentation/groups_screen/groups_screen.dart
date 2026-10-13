import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../services/group_change_notifier.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import './widgets/group_card_widget.dart';
import './widgets/group_members_sheet_widget.dart';
import './widgets/invite_sheet_widget.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _error;

  /// Whether the current user has the can_create_groups capability.
  bool _canCreateGroups = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.instance.getMyGroups(),
        SupabaseService.instance.canCreateGroups(),
      ]);
      if (mounted) {
        setState(() {
          _groups = results[0] as List<Map<String, dynamic>>;
          _canCreateGroups = results[1] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar grupos';
          _isLoading = false;
        });
      }
    }
  }

  void _showInviteSheet(String groupId, String groupName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteSheetWidget(groupName: groupName, groupId: groupId),
    );
  }

  void _showMembersSheet(Map<String, dynamic> group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupMembersSheetWidget(group: group),
    );
  }

  void _showCreateGroupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CreateGroupSheet(
        onGroupCreated: (name, description) async {
          // Use atomic RPC — single transaction, rolls back on any failure
          try {
            final group = await SupabaseService.instance.createGroupAsOwner(
              name: name,
              description: description,
            );
            if (group == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No se pudo crear el grupo. Verifica tus permisos.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return false;
            }
            if (!mounted) return false;
            // Close the create sheet ONLY after a confirmed creation, and
            // only if it is still the top route (user may have dismissed it)
            if (ModalRoute.of(sheetContext)?.isCurrent ?? false) {
              Navigator.pop(sheetContext);
            }
            final groupId = group['id'] as String;
            await _loadGroups();
            // Notify map to refresh AND auto-select the new group
            GroupChangeNotifier.instance.notifyGroupsChangedWithActiveGroup(
              groupId,
            );
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _showInviteSheet(groupId, name);
              }
            });
            return true;
          } catch (_) {
            // Never leave an unhandled async exception: the sheet stays
            // open, the spinner resets and the user sees why it failed.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error al crear el grupo. Inténtalo de nuevo.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: AppTheme.primaryContainer,
        title: Text(
          'Mis grupos',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.primary,
            onPressed: _loadGroups,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(color: AppTheme.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadGroups,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : _groups.isEmpty
            // ── EMPTY STATE ──────────────────────────────────────────────
            // Admin with can_create_groups: show ONE create CTA (no FAB)
            // Member without capability: show informational empty state only
            ? EmptyStateWidget(
                icon: Icons.group_add_rounded,
                title: 'Sin grupos todavía',
                description: _canCreateGroups
                    ? 'Crea un grupo familiar o de confianza para empezar a coordinarte en el mapa.'
                    : 'Aún no perteneces a ningún grupo. Pide a un administrador que te invite.',
                ctaLabel: _canCreateGroups ? '+ Crear grupo' : null,
                onCta: _canCreateGroups ? _showCreateGroupDialog : null,
              )
            : RefreshIndicator(
                onRefresh: _loadGroups,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final group = _groups[i];
                    final myRole = (group['myRole'] as String?) ?? 'member';
                    final isAdmin = SupabaseService.instance.isAdminRole(
                      myRole,
                    );
                    return GroupCardWidget(
                      group: group,
                      onTap: () => _showMembersSheet(group),
                      onInvite: isAdmin
                          ? () => _showInviteSheet(
                              group['id'] as String,
                              group['name'] as String,
                            )
                          : null,
                    );
                  },
                ),
              ),
      ),
      // ── FAB ─────────────────────────────────────────────────────────────
      // Show "Nuevo grupo" FAB ONLY when:
      //   • user has can_create_groups capability
      //   • AND user already has at least one group (non-empty state)
      // Empty state uses the inline CTA instead — never show both.
      floatingActionButton: (_canCreateGroups && _groups.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _showCreateGroupDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo grupo'),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  final Future<bool> Function(String name, String description) onGroupCreated;

  const _CreateGroupSheet({required this.onGroupCreated});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedEmoji = '👨‍👩‍👧‍👦';
  String _selectedColor = 'teal';
  bool _isCreating = false;

  final List<String> _emojis = [
    '👨‍👩‍👧‍👦',
    '🏠',
    '🚗',
    '⚽',
    '🏔️',
    '🌍',
    '💼',
    '🎓',
    '❤️',
    '🛡️',
  ];

  final Map<String, Color> _colors = {
    'teal': AppTheme.primary,
    'blue': const Color(0xFF1565C0),
    'purple': const Color(0xFF7B1FA2),
    'orange': const Color(0xFFE65100),
    'red': const Color(0xFFB71C1C),
    'green': const Color(0xFF2E7D32),
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.group_add_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Crear nuevo grupo',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showEmojiPicker(context),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: (_colors[_selectedColor] ?? AppTheme.primary)
                                .withAlpha(30),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  (_colors[_selectedColor] ?? AppTheme.primary)
                                      .withAlpha(80),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _selectedEmoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre del grupo',
                            hintText: 'Ej: Familia García',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Ej: Hogar principal · Madrid',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Color del grupo',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _colors.entries.map((entry) {
                      final isSelected = _selectedColor == entry.key;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 10),
                          width: isSelected ? 36 : 30,
                          height: isSelected ? 36 : 30,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white,
                                    width: 2,
                                    strokeAlign: BorderSide.strokeAlignOutside,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: entry.value.withAlpha(100),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isCreating
                          ? null
                          : () async {
                              if (_nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Escribe un nombre para el grupo',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() => _isCreating = true);
                              // Always reset the spinner — success closes the
                              // sheet from the parent; failure keeps it open.
                              try {
                                await widget.onGroupCreated(
                                  _nameController.text.trim(),
                                  _descController.text.trim().isEmpty
                                      ? 'Grupo creado ahora'
                                      : _descController.text.trim(),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isCreating = false);
                                }
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Crear grupo e invitar',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elige un icono'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _emojis.map((e) {
            return GestureDetector(
              onTap: () {
                setState(() => _selectedEmoji = e);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
