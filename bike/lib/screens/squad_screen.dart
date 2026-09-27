import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/squad_provider.dart';
import '../../models/rider_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/squad_widgets.dart';
import 'group_detail_screen.dart';
import '../widgets/community_dialogs.dart';

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _openCreateGroupFlow(BuildContext context) async {
    final squadProvider = context.read<SquadProvider>();
    final groupId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: squadProvider,
          child: const _SquadCreationScreen(),
        ),
      ),
    );

    if (!mounted || groupId == null) return;
    final group = squadProvider.groups.firstWhere(
      (group) => group.id == groupId,
    );
    squadProvider.setActiveGroup(group);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: squadProvider,
          child: GroupDetailScreen(groupId: group.id),
        ),
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, SquadProvider squad) {
    final groupName = squad.activeGroup?.name ?? 'Group';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.red, width: 1.2),
        ),
        title: const Text(
          'Delete Group',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "$groupName"? This action cannot be undone.',
          style: TextStyle(color: AppColors.themedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.themedGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (squad.activeGroup != null) {
                squad.deleteGroup(squad.activeGroup!.id);
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Squad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Group',
            onPressed: () => _openCreateGroupFlow(context),
          ),
          Consumer<SquadProvider>(
            builder: (context, squad, _) {
              final canDelete =
                  squad.activeGroup != null &&
                  squad.activeGroup!.isLeader(squad.currentUserId);
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Group',
                onPressed: canDelete
                    ? () => _showDeleteGroupDialog(context, squad)
                    : null,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Join Squad',
            onPressed: () => showJoinSquadDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<SquadProvider>(
        builder: (context, squad, _) {
          if (squad.groups.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: squad.groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final group = squad.groups[i];
              return _buildGroupCard(context, group, i);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateGroupFlow(context),
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.themedText,
        icon: const Icon(Icons.group_add),
        label: const Text(
          'New Group',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.orangeGlow,
              border: Border.all(color: AppColors.orange, width: 1.5),
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: AppColors.orange,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'You have not joined a squad yet.',
            style: TextStyle(
              color: AppColors.themedText,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join or create a squad to access group chat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _openCreateGroupFlow(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.themedText,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Create First Group',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, RiderGroup group, int index) {
    final isLeader =
        context.read<SquadProvider>().currentUserId == group.leaderId;

    return SlideTransition(
      position:
          Tween<Offset>(
            begin: Offset(0, 0.3 + index * 0.1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animController,
              curve: Interval(index * 0.1, 1.0, curve: Curves.easeOutCubic),
            ),
          ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Interval(index * 0.1, 1.0),
          ),
        ),
        child: OrangeCard(
          onTap: () {
            context.read<SquadProvider>().setActiveGroup(group);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<SquadProvider>(),
                  child: GroupDetailScreen(groupId: group.id),
                ),
              ),
            );
          },
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.orangeGlow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups,
                      color: AppColors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            color: AppColors.themedText,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${group.kind.displayName} - ${group.members.length} rider${group.members.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLeader)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeGlow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        '👑 LEADER',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: AppColors.themedGrey),
                ],
              ),
              if (group.members.length > 1) ...[
                const SizedBox(height: 14),
                Divider(color: AppColors.themedGreyBorder, height: 1),
                const SizedBox(height: 12),
                // Member avatar row
                SizedBox(
                  height: 40,
                  child: Stack(
                    children: [
                      for (int i = 0; i < group.members.length.clamp(0, 5); i++)
                        Positioned(
                          left: i * 28.0,
                          child: RiderAvatar(
                            rider: group.members[i],
                            size: 36,
                            showBadge: false,
                          ),
                        ),
                      if (group.members.length > 5)
                        Positioned(
                          left: 5 * 28.0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.themedGreyBorder,
                              border: Border.all(
                                color: AppColors.orange,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '+${group.members.length - 5}',
                                style: const TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SquadCreationScreen extends StatefulWidget {
  const _SquadCreationScreen();

  @override
  State<_SquadCreationScreen> createState() => _SquadCreationScreenState();
}

class _SquadCreationScreenState extends State<_SquadCreationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();
  final List<_DraftMember> _members = [];
  SquadKind _kind = SquadKind.squad;
  int _step = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  int? get _memberLimit => _kind.maxAdditionalMembers;

  bool get _canAddMember {
    final limit = _memberLimit;
    return limit == null || _members.length < limit;
  }

  void _selectKind(SquadKind kind) {
    setState(() {
      _kind = kind;
      final limit = _memberLimit;
      if (limit != null && _members.length > limit) {
        _members.removeRange(limit, _members.length);
      }
    });
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty || !_canAddMember) return;

    setState(() {
      _members.add(
        _DraftMember(
          name: name,
          role: _kind == SquadKind.duo
              ? RiderRole.coLeader
              : RiderRole.midRider,
        ),
      );
      _memberController.clear();
    });
  }

  void _goNext() {
    if (_step == 0 && _nameController.text.trim().isEmpty) return;
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }

    final group = context.read<SquadProvider>().createConfiguredGroup(
      name: _nameController.text.trim(),
      kind: _kind,
      members: _members
          .map(
            (member) => SquadMemberSetup(name: member.name, role: member.role),
          )
          .toList(),
    );
    Navigator.pop(context, group.id);
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('New Squad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepHeader(step: _step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildStep(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.themedGrey,
                        side: BorderSide(color: AppColors.themedGreyBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_step == 0 ? 'Cancel' : 'Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.themedText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_step == 2 ? 'Create' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildTypeStep();
      case 1:
        return _buildMembersStep();
      default:
        return _buildPositionsStep();
    }
  }

  Widget _buildTypeStep() {
    return Column(
      key: const ValueKey('type-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Squad details',
          style: TextStyle(
            color: AppColors.themedText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _nameController,
          autofocus: true,
          style: TextStyle(color: AppColors.themedText),
          decoration: InputDecoration(
            hintText: 'Squad name',
            hintStyle: TextStyle(color: AppColors.themedGrey),
            prefixIcon: const Icon(Icons.edit, color: AppColors.orange),
            filled: true,
            fillColor: AppColors.themedCard,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.themedGreyBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Ride setup',
          style: TextStyle(
            color: AppColors.orange,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        _KindChoice(
          kind: SquadKind.solo,
          selected: _kind == SquadKind.solo,
          icon: Icons.person,
          onTap: () => _selectKind(SquadKind.solo),
        ),
        const SizedBox(height: 10),
        _KindChoice(
          kind: SquadKind.duo,
          selected: _kind == SquadKind.duo,
          icon: Icons.people,
          onTap: () => _selectKind(SquadKind.duo),
        ),
        const SizedBox(height: 10),
        _KindChoice(
          kind: SquadKind.squad,
          selected: _kind == SquadKind.squad,
          icon: Icons.groups,
          onTap: () => _selectKind(SquadKind.squad),
        ),
      ],
    );
  }

  Widget _buildMembersStep() {
    final limit = _memberLimit;
    final memberCountText = limit == null
        ? '${_members.length} added'
        : '${_members.length}/$limit added';

    return Column(
      key: const ValueKey('members-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add members',
          style: TextStyle(
            color: AppColors.themedText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _kind == SquadKind.solo
              ? 'Solo squads only include you.'
              : memberCountText,
          style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (_kind != SquadKind.solo)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _memberController,
                  enabled: _canAddMember,
                  style: TextStyle(color: AppColors.themedText),
                  onSubmitted: (_) => _addMember(),
                  decoration: InputDecoration(
                    hintText: _canAddMember ? 'Rider name' : 'Member limit hit',
                    hintStyle: TextStyle(color: AppColors.themedGrey),
                    filled: true,
                    fillColor: AppColors.themedCard,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.themedGreyBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.orange,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed: _canAddMember ? _addMember : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.themedText,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        _MemberPreview(
          name: 'You (Leader)',
          role: RiderRole.leader,
          onRemove: null,
        ),
        const SizedBox(height: 10),
        ..._members.map(
          (member) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemberPreview(
              name: member.name,
              role: member.role,
              onRemove: () => setState(() => _members.remove(member)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionsStep() {
    return Column(
      key: const ValueKey('positions-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Positions',
          style: TextStyle(
            color: AppColors.themedText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose how each rider sits in the formation.',
          style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _PositionRow(
          name: 'You (Leader)',
          role: RiderRole.leader,
          locked: true,
          onChanged: null,
        ),
        const SizedBox(height: 10),
        ..._members.map(
          (member) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PositionRow(
              name: member.name,
              role: member.role,
              locked: false,
              onChanged: (role) => setState(() => member.role = role),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftMember {
  final String name;
  RiderRole role;

  _DraftMember({required this.name, required this.role});
}

class _StepHeader extends StatelessWidget {
  final int step;

  const _StepHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Type', 'Members', 'Positions'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? AppColors.orange
                          : AppColors.themedGreyBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: i == step
                          ? AppColors.orange
                          : AppColors.themedGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (i != labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _KindChoice extends StatelessWidget {
  final SquadKind kind;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _KindChoice({
    required this.kind,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OrangeCard(
      onTap: onTap,
      borderColor: selected ? AppColors.orange : AppColors.themedGreyBorder,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.orangeGlow
                  : AppColors.themedGreyBorder,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.displayName,
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  kind.description,
                  style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.orange : AppColors.themedGrey,
          ),
        ],
      ),
    );
  }
}

class _MemberPreview extends StatelessWidget {
  final String name;
  final RiderRole role;
  final VoidCallback? onRemove;

  const _MemberPreview({
    required this.name,
    required this.role,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return OrangeCard(
      borderColor: AppColors.themedGreyBorder,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                RoleChip(role: role, compact: true),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, color: AppColors.themedGrey),
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  final String name;
  final RiderRole role;
  final bool locked;
  final void Function(RiderRole role)? onChanged;

  const _PositionRow({
    required this.name,
    required this.role,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OrangeCard(
      borderColor: locked ? AppColors.orange : AppColors.themedGreyBorder,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          if (locked)
            RoleChip(role: role, compact: true)
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<RiderRole>(
                value: role,
                dropdownColor: AppColors.themedSurface,
                iconEnabledColor: AppColors.orange,
                style: TextStyle(color: AppColors.themedText),
                items: RiderRole.values
                    .where((role) => role != RiderRole.leader)
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (role) {
                  if (role != null) onChanged?.call(role);
                },
              ),
            ),
        ],
      ),
    );
  }
}
