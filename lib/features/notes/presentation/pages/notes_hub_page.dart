import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../shell/presentation/providers/main_nav_provider.dart';
import '../providers/notes_hub_provider.dart';

class NotesHubPage extends StatefulWidget {
  const NotesHubPage({super.key});

  @override
  State<NotesHubPage> createState() => _NotesHubPageState();
}

class _NotesHubPageState extends State<NotesHubPage> {
  MainNavProvider? _nav;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesHubProvider>().load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<MainNavProvider>();
    if (!identical(_nav, nav)) {
      _nav?.removeListener(_onNavChanged);
      _nav = nav;
      _nav?.addListener(_onNavChanged);
    }
  }

  void _onNavChanged() {
    if (!mounted) return;
    if (_nav?.index == 2) {
      context.read<NotesHubProvider>().load();
    }
  }

  @override
  void dispose() {
    _nav?.removeListener(_onNavChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<NotesHubProvider>();
    final rs = context.rs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => hub.load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ResponsiveBody(
        mode: ResponsiveMode.fill,
        child: hub.loading && hub.groups.isEmpty
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: hub.load,
                child: ListView(
                  padding: EdgeInsets.only(bottom: rs.scale(24)),
                  children: [
                    if (hub.error != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: rs.scale(12)),
                        child: Text(
                          hub.error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(
                      'Notes by book',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: rs.font(18),
                      ),
                    ),
                    SizedBox(height: rs.scale(4)),
                    Text(
                      hub.groups.isEmpty
                          ? 'Add notes while reading a book — they show up here.'
                          : '${hub.groups.length} books with notes',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: rs.scale(16)),
                    if (hub.groups.isEmpty)
                      AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.sticky_note_2_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Open any book from Library, add a note on a page, then come back.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...hub.groups.map((group) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: rs.scale(10)),
                          child: AppCard(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.bookNotes,
                                arguments: {
                                  'bookId': group.bookId,
                                  'bookTitle': group.bookTitle,
                                },
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondarySoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.bookTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        group.subject.isEmpty
                                            ? '${group.count} notes'
                                            : '${group.subject} · ${group.count} notes',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${group.count}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}
