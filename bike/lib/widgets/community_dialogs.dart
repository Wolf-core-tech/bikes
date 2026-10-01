import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/community_models.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/squad_provider.dart';
import '../theme/app_theme.dart';

Future<void> showAddRiderDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _AddRiderDialog());

Future<void> showJoinSquadDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _JoinSquadDialog());

class _AddRiderDialog extends StatefulWidget {
  const _AddRiderDialog();

  @override
  State<_AddRiderDialog> createState() => _AddRiderDialogState();
}

class _AddRiderDialogState extends State<_AddRiderDialog> {
  final _searchController = TextEditingController();
  UserModel? _result;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final current = auth.currentUser;
    final community = context.watch<CommunityProvider>();
    final currentId = current?.uid ?? current?.email.trim().toLowerCase() ?? '';
    final status = _result == null
        ? 'Send Request'
        : community.requestStatus(
            currentId,
            _result!.uid ?? _result!.email.trim().toLowerCase(),
          );

    return AlertDialog(
      backgroundColor: AppColors.themedSurface,
      title: const Text('Add Rider'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: AppColors.themedText),
              decoration: const InputDecoration(
                labelText: 'Gmail or username',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _search,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.orangeGlow,
                  child: Text(_initials(_result!.name)),
                ),
                title: Text(_result!.name),
                subtitle: Text(_result!.email),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: status == 'Send Request' ? _sendRequest : null,
                  child: Text(status),
                ),
              ),
            ],
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _message!,
                  style: TextStyle(color: AppColors.orange),
                  textAlign: TextAlign.center,
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Invite Ride'),
                onPressed: current == null ? null : _createInvitation,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _search() async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() {
      _busy = true;
      _message = null;
      _result = null;
    });

    final auth = context.read<AuthProvider>();
    final currentId =
        auth.currentUser?.uid ??
        auth.currentUser?.email.trim().toLowerCase() ??
        '';

    UserModel? result;
    String? errorMessage;
    try {
      result = await context.read<CommunityProvider>().searchUser(
        _searchController.text,
        currentId,
      );
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!mounted) return;

    setState(() {
      _result = result;
      if (errorMessage != null) {
        _message = errorMessage.replaceAll('Exception: ', '');
      } else {
        _message = _result == null
            ? 'Rider not found. Ask them to open Bike Squad and log in once, then search again.'
            : null;
      }
      _busy = false;
    });
  }

  Future<void> _sendRequest() async {
    final sender = context.read<AuthProvider>().currentUser;
    final receiver = _result;
    if (sender == null || receiver == null) return;
    setState(() => _busy = true);
    final message = await context.read<CommunityProvider>().sendFriendRequest(
      sender: sender,
      receiver: receiver,
    );
    if (mounted) {
      setState(() {
        _message = message;
        _busy = false;
      });
    }
  }

  Future<void> _createInvitation() async {
    final auth = context.read<AuthProvider>();
    final squad = context.read<SquadProvider>();
    final group = squad.activeGroup;
    final user = auth.currentUser;
    if (group == null || user == null) {
      setState(() => _message = 'Create or select a squad first.');
      return;
    }
    if (!group.isLeader(squad.currentUserId)) {
      setState(() => _message = 'Only the squad owner can create invitations.');
      return;
    }
    final invitation = await context.read<CommunityProvider>().createInvitation(
      squadId: group.id,
      squadName: group.name,
      creatorId: squad.currentUserId,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _InvitationDialog(invitation: invitation),
    );
  }

  String _initials(String name) => name.trim().isEmpty
      ? '?'
      : name
            .trim()
            .split(RegExp(r'\s+'))
            .map((part) => part[0])
            .take(2)
            .join()
            .toUpperCase();
}

class _InvitationDialog extends StatelessWidget {
  final SquadInvitation invitation;

  const _InvitationDialog({required this.invitation});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.themedSurface,
    title: const Text('Invite Rider'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(invitation.squadName),
        const SizedBox(height: 14),
        Text(
          invitation.code,
          style: TextStyle(
            color: AppColors.orange,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Share this code with a rider. It expires in 24 hours.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invitation.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invitation code copied.')),
                );
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              onPressed: () => Share.share(
                'Join my ${invitation.squadName} squad with code ${invitation.code}.',
              ),
            ),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _JoinSquadDialog extends StatefulWidget {
  const _JoinSquadDialog();

  @override
  State<_JoinSquadDialog> createState() => _JoinSquadDialogState();
}

class _JoinSquadDialogState extends State<_JoinSquadDialog> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  String? _message;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.themedSurface,
    title: const Text('Join Squad'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Enter the 4-digit invitation code.'),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, _digitField),
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          Text(_message!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(onPressed: _join, child: const Text('Join Squad')),
    ],
  );

  Widget _digitField(int index) => SizedBox(
    width: 42,
    child: TextField(
      controller: _controllers[index],
      focusNode: _focusNodes[index],
      autofocus: index == 0,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      maxLength: 1,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(counterText: ''),
      onChanged: (value) {
        if (value.length == 1 && index < 3) {
          _focusNodes[index + 1].requestFocus();
        }
        if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
      },
    ),
  );

  Future<void> _join() async {
    final code = _controllers.map((controller) => controller.text).join();
    if (code.length != 4) {
      setState(() => _message = 'Enter exactly 4 digits.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final squad = context.read<SquadProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    final message = await context
        .read<CommunityProvider>()
        .validateAndUseInvitation(
          code: code,
          currentUserId: squad.currentUserId,
          isAlreadyMember: (squadId) =>
              squad.isMember(squadId, squad.currentUserId),
          addMember: (groupId) => squad.loadJoinedGroup(groupId),
        );
    if (!mounted) return;
    if (message == 'You joined the squad successfully.') {
      Navigator.pop(context);
    } else {
      setState(() => _message = message);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
