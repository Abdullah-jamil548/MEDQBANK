import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/step_progress.dart';
import '../../../../domain/entities/mbbs_year.dart';
import '../providers/profile_setup_provider.dart';

class ProfileSetupPage extends StatelessWidget {
  const ProfileSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final setup = context.watch<ProfileSetupProvider>();

    final rs = context.rs;

    return Scaffold(
      body: ResponsiveBody(
        mode: ResponsiveMode.fill,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBackButton(
              onPressed: () {
                if (setup.step == 1) {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
                  return;
                }
                setup.goBack();
              },
            ),
            SizedBox(height: rs.scale(16)),
            StepProgress(current: setup.step, total: 3),
            SizedBox(height: rs.scale(28)),
            Text(
              switch (setup.step) {
                1 => AppStrings.tellUsAboutYourself,
                2 => AppStrings.selectMbbsYear,
                _ => AppStrings.selectInstitute,
              },
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: rs.font(24),
                    letterSpacing: -0.4,
                  ),
            ),
            SizedBox(height: rs.scale(6)),
            Text(
              switch (setup.step) {
                1 => 'This helps personalize your dashboard.',
                2 => 'We will show books and MCQs for your year.',
                _ => 'Search and tap your medical college.',
              },
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: rs.font(14),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: rs.scale(24)),
            Expanded(
              child: switch (setup.step) {
                1 => const _IdentityStep(),
                2 => const _YearStep(),
                _ => const _CollegeStep(),
              },
            ),
            PrimaryButton(
              label: AppStrings.continueLabel,
              onPressed: () {
                final finished = setup.continueStep();
                if (finished && context.mounted) {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.notifications);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep();

  @override
  Widget build(BuildContext context) {
    final setup = context.watch<ProfileSetupProvider>();

    return SingleChildScrollView(
      child: Column(
        children: [
          GestureDetector(
            onTap: setup.toggleAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primarySoft,
                  child: setup.hasAvatar
                      ? Text(
                          setup.nameController.text.trim().isEmpty
                              ? 'You'
                              : setup.nameController.text.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 42,
                          color: AppColors.primary,
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap to add a photo',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: setup.nameController,
            label: AppStrings.fullName,
            hint: 'How should we greet you?',
            prefixIcon: Icons.person_outline_rounded,
            onChanged: setup.onNameChanged,
            errorText: setup.nameError,
          ),
        ],
      ),
    );
  }
}

class _YearStep extends StatelessWidget {
  const _YearStep();

  @override
  Widget build(BuildContext context) {
    final setup = context.watch<ProfileSetupProvider>();

    return ListView(
      children: [
        ...MbbsYear.values.map((year) {
          final selected = setup.selectedYear == year;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: selected ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: InkWell(
                onTap: () => setup.selectYear(year),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          year.shortLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        year.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (setup.yearError != null)
          Text(
            setup.yearError!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
      ],
    );
  }
}

class _CollegeStep extends StatelessWidget {
  const _CollegeStep();

  @override
  Widget build(BuildContext context) {
    final setup = context.watch<ProfileSetupProvider>();

    return Column(
      children: [
        AppTextField(
          controller: setup.searchController,
          hint: AppStrings.searchCollege,
          prefixIcon: Icons.search_rounded,
          onChanged: setup.onCollegeQueryChanged,
          errorText: setup.collegeError,
        ),
        const SizedBox(height: 12),
        if (setup.selectedCollege != null && !setup.showCollegeResults)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setup.selectedCollege!.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        setup.selectedCollege!.city,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (setup.showCollegeResults || setup.selectedCollege == null)
          Expanded(
            child: ListView.separated(
              itemCount: setup.colleges.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final college = setup.colleges[index];
                final selected = setup.selectedCollege?.id == college.id;
                return ListTile(
                  onTap: () => setup.selectCollege(college),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    college.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(college.city),
                  trailing: selected
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                );
              },
            ),
          )
        else
          const Spacer(),
      ],
    );
  }
}
