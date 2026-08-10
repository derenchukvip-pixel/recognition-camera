import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/origin_preferences.dart';
import '../common/tab_scaffold.dart';
import '../design/tokens.dart';
import 'origin_preferences_view_model.dart';

class OriginPreferencesTab extends StatefulWidget {
  const OriginPreferencesTab({super.key});

  @override
  State<OriginPreferencesTab> createState() => _OriginPreferencesTabState();
}

class _OriginPreferencesTabState extends State<OriginPreferencesTab> {
  final TextEditingController _preferredController = TextEditingController();
  final TextEditingController _avoidedController = TextEditingController();
  final FocusNode _preferredFocus = FocusNode();
  final FocusNode _avoidedFocus = FocusNode();

  @override
  void dispose() {
    _preferredController.dispose();
    _avoidedController.dispose();
    _preferredFocus.dispose();
    _avoidedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OriginPreferencesViewModel>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: TabScaffold(
        title: 'Preferences',
        subtitle: 'Which origins you want pointed out',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            const _WhatThisDoes(),
            const SizedBox(height: AppSpacing.lg),
            _PreferenceSection(
              title: 'Countries you prefer',
              hint: 'A result that names one of these will point it out.',
              accent: AppColors.verified,
              controller: _preferredController,
              focusNode: _preferredFocus,
              suggestions: _suggestions(_preferredController.text, viewModel),
              onQueryChanged: (_) => setState(() {}),
              onSelected: (country) async {
                await viewModel.addAligned(country);
                _preferredController.clear();
                if (mounted) setState(() {});
              },
              countries: viewModel.aligned,
              onRemove: viewModel.removeAligned,
              emptyHint: 'No countries yet. Add one to have it pointed out.',
            ),
            const SizedBox(height: AppSpacing.md),
            _PreferenceSection(
              title: 'Countries you would rather avoid',
              hint: 'Pointed out the same way, so you can decide for yourself.',
              accent: AppColors.negative,
              controller: _avoidedController,
              focusNode: _avoidedFocus,
              suggestions: _suggestions(_avoidedController.text, viewModel),
              onQueryChanged: (_) => setState(() {}),
              onSelected: (country) async {
                await viewModel.addLessAligned(country);
                _avoidedController.clear();
                if (mounted) setState(() {});
              },
              countries: viewModel.lessAligned,
              onRemove: viewModel.removeLessAligned,
              emptyHint: 'No countries yet.',
            ),
          ],
        ),
      ),
    );
  }

  List<String> _suggestions(
    String query,
    OriginPreferencesViewModel viewModel,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final chosen = {
      ...viewModel.aligned.map(OriginPreferences.normalize),
      ...viewModel.lessAligned.map(OriginPreferences.normalize),
    };
    return OriginPreferences.allCountries
        .where((country) {
          final key = OriginPreferences.normalize(country);
          return key.contains(normalized) && !chosen.contains(key);
        })
        .take(5)
        .toList();
  }
}

/// The explanation that keeps this feature from undoing the rest of the app.
///
/// A country matching a preference gets marked on the result screen, and a
/// mark next to a country is very easily read as "confirmed". It is not: it
/// means the text matched a list the user typed. The provenance badge is the
/// only thing that says whether the country is reliable, and the two must not
/// be confused — otherwise the app is back to decorating guesses with ticks.
class _WhatThisDoes extends StatelessWidget {
  const _WhatThisDoes();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW THESE LISTS ARE USED', style: AppText.label),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'When a scan mentions a country on one of your lists, the result '
            'points it out.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'That is a match against your own settings — not a check of '
            'whether the country is correct. Whether a country can be trusted '
            'at all is what the Verified, Estimated and Unknown badges are '
            'for, and they are decided independently of anything here.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({
    required this.title,
    required this.hint,
    required this.accent,
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.onQueryChanged,
    required this.onSelected,
    required this.countries,
    required this.onRemove,
    required this.emptyHint,
  });

  final String title;
  final String hint;
  final Color accent;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> suggestions;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelected;
  final List<String> countries;
  final ValueChanged<String> onRemove;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          Text(hint, style: AppText.caption),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: 'Add a country',
              hintStyle: AppText.body.copyWith(color: AppColors.inkMuted),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.inkMuted,
              ),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              border: const OutlineInputBorder(
                borderRadius: AppRadius.cardRadius,
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.cardRadius,
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.cardRadius,
                borderSide: BorderSide(color: AppColors.brandBright, width: 2),
              ),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final country in suggestions)
              _SuggestionRow(
                country: country,
                onTap: () => onSelected(country),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (countries.isEmpty)
            Text(emptyHint, style: AppText.caption)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final country in countries)
                  _CountryChip(
                    country: country,
                    accent: accent,
                    onRemove: () => onRemove(country),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.country, required this.onTap});

  final String country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.sm),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const Icon(Icons.add, size: 18, color: AppColors.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(country, style: AppText.body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chosen country.
///
/// The accent tints the border and the label, never the whole chip: a solid
/// green or red block here would look like the provenance badges, which are
/// the one thing on screen that colour is reserved for.
class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.country,
    required this.accent,
    required this.onRemove,
  });

  final String country;
  final Color accent;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(country, style: AppText.body.copyWith(color: accent)),
          const SizedBox(width: AppSpacing.xs),
          Semantics(
            button: true,
            label: 'Remove $country',
            child: InkResponse(
              onTap: onRemove,
              radius: 20,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.close, size: 16, color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
