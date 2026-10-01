import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../providers/chat_provider.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.instance.requestPermission();
      if (!mounted) return;
      context.read<ChatProvider>().loadThreads();
      context.read<FriendsProvider>().refresh(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final friends = context.watch<FriendsProvider>();
    final rs = context.rs;

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ResponsiveBody(
        mode: ResponsiveMode.scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chat.error != null)
              Padding(
                padding: EdgeInsets.only(bottom: rs.scale(12)),
                child: Text(
                  chat.error!,
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
              ),
            if (chat.loadingThreads && chat.threads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (chat.threads.isEmpty && friends.friends.isEmpty)
              AppCard(
                child: Text(
                  'Add friends first, then start a chat from their profile card.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: rs.font(14),
                  ),
                ),
              )
            else ...[
              if (chat.threads.isNotEmpty) ...[
                const SectionLabel('Recent'),
                SizedBox(height: rs.scale(10)),
                ...chat.threads.map((thread) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: rs.scale(10)),
                    child: AppCard(
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.chatThread,
                          arguments: {
                            'friendUserId': thread.friendUserId,
                            'friendName': thread.fullName,
                          },
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              thread.initials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        thread.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ),
                                    if (thread.lastMessage != null)
                                      Text(
                                        ChatProvider.formatMessageTime(thread.lastMessage!.createdAt),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (thread.muted) ...[
                                      const Icon(Icons.notifications_off, size: 14, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        thread.lastMessage?.preview ?? 'No messages yet',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (thread.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${thread.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(height: rs.scale(16)),
              ],
              const SectionLabel('Friends'),
              SizedBox(height: rs.scale(10)),
              ...friends.friends.map((friend) {
                return Padding(
                  padding: EdgeInsets.only(bottom: rs.scale(10)),
                  child: AppCard(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.chatThread,
                        arguments: {
                          'friendUserId': friend.userId,
                          'friendName': friend.fullName,
                        },
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.secondarySoft,
                          child: Text(
                            friend.initials,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                friend.email,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
