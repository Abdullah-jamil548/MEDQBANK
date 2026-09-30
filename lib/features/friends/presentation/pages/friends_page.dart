import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/friend.dart';
import '../providers/friends_provider.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatLastSeen(DateTime? at) {
    if (at == null) return 'Last seen unknown';
    final local = at.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Last seen ${diff.inDays}d ago';
    return 'Last seen ${local.day}/${local.month}/${local.year}';
  }

  String _readingLabel(FriendReadingActivity? reading) {
    if (reading == null) return 'No recent reading';
    final pct = reading.progressPct;
    final pctText = pct == null ? '' : ' · ${(pct * 100).round()}%';
    return '${reading.bookTitle} · p.${reading.pageNo}$pctText';
  }

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendsProvider>();
    final rs = context.rs;
    final incoming = friends.requests.where((r) => r.isIncoming).toList();
    final outgoing = friends.requests.where((r) => !r.isIncoming).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            onPressed: friends.loading ? null : () => friends.refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ResponsiveBody(
        mode: ResponsiveMode.scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find by email',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            SizedBox(height: rs.scale(10)),
            AppTextField(
              controller: _searchController,
              label: 'Email',
              hint: 'friend@example.com',
              prefixIcon: Icons.search_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              onChanged: (value) => friends.search(value),
            ),
            if (friends.searching) ...[
              SizedBox(height: rs.scale(12)),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
            if (friends.searchError != null) ...[
              SizedBox(height: rs.scale(8)),
              Text(
                friends.searchError!,
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ],
            if (friends.searchHits.isNotEmpty) ...[
              SizedBox(height: rs.scale(12)),
              ...friends.searchHits.map((hit) => _SearchHitTile(hit: hit)),
            ],
            if (friends.error != null) ...[
              SizedBox(height: rs.scale(12)),
              Text(
                friends.error!,
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ],
            SizedBox(height: rs.scale(24)),
            if (incoming.isNotEmpty) ...[
              const SectionLabel('Friend requests'),
              SizedBox(height: rs.scale(10)),
              ...incoming.map(
                (req) => Padding(
                  padding: EdgeInsets.only(bottom: rs.scale(10)),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          req.email,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: rs.scale(12)),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: friends.acting
                                    ? null
                                    : () async {
                                        final ok = await friends.accept(req.friendshipId);
                                        if (!context.mounted || !ok) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('You are now friends with ${req.fullName}')),
                                        );
                                      },
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: friends.acting
                                    ? null
                                    : () => friends.decline(req.friendshipId),
                                child: const Text('Decline'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: rs.scale(12)),
            ],
            if (outgoing.isNotEmpty) ...[
              const SectionLabel('Sent requests'),
              SizedBox(height: rs.scale(10)),
              ...outgoing.map(
                (req) => Padding(
                  padding: EdgeInsets.only(bottom: rs.scale(10)),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                req.email,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Pending',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: friends.acting
                              ? null
                              : () => friends.decline(req.friendshipId),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: rs.scale(12)),
            ],
            const SectionLabel('Your friends'),
            SizedBox(height: rs.scale(10)),
            if (friends.loading && friends.friends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (friends.friends.isEmpty)
              AppCard(
                child: Text(
                  'No friends yet. Search by email above to send a request.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: rs.font(14),
                  ),
                ),
              )
            else
              ...friends.friends.map(
                (friend) => Padding(
                  padding: EdgeInsets.only(bottom: rs.scale(10)),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primarySoft,
                                  child: Text(
                                    friend.initials,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (friend.isOnline == true)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    friend.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    friend.email,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    friend.presenceHidden
                                        ? 'Status hidden'
                                        : friend.isOnline == true
                                            ? 'Online'
                                            : _formatLastSeen(friend.lastSeenAt),
                                    style: TextStyle(
                                      color: friend.isOnline == true
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    friend.readingHidden
                                        ? 'Reading activity hidden'
                                        : _readingLabel(friend.lastReading),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Chat',
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.chatThread,
                                  arguments: {
                                    'friendUserId': friend.userId,
                                    'friendName': friend.fullName,
                                  },
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline_rounded),
                            ),
                            IconButton(
                              tooltip: 'Remove friend',
                              onPressed: friends.acting
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Remove friend?'),
                                          content: Text(
                                            'Remove ${friend.fullName} from your friends?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await friends.remove(friend.friendshipId);
                                      }
                                    },
                              icon: const Icon(Icons.person_remove_outlined),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchHitTile extends StatelessWidget {
  const _SearchHitTile({required this.hit});

  final UserSearchHit hit;

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendsProvider>();
    final status = hit.friendshipStatus;
    String actionLabel = 'Add';
    VoidCallback? onPressed = () async {
      final ok = await friends.sendRequest(hit.email);
      if (!context.mounted || !ok) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${hit.fullName}')),
      );
    };

    if (status == 'accepted') {
      actionLabel = 'Friends';
      onPressed = null;
    } else if (status == 'pending') {
      actionLabel = hit.direction == 'incoming' ? 'Respond below' : 'Pending';
      onPressed = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hit.email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: friends.acting ? null : onPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
