import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/origin_preferences.dart';
import 'origin_preferences_view_model.dart';

class OriginPreferencesTab extends StatefulWidget {
  const OriginPreferencesTab({super.key});

  @override
  State<OriginPreferencesTab> createState() => _OriginPreferencesTabState();
}

class _OriginPreferencesTabState extends State<OriginPreferencesTab> {
  static const Color _primaryBlue = Color(0xFF052F61);
  static const Color _alignedGreen = Color(0xFF1A7F4A);
  static const Color _warningRed = Color(0xFFB11C1C);

  final TextEditingController _alignedController = TextEditingController();
  final TextEditingController _lessAlignedController = TextEditingController();
  final FocusNode _alignedFocus = FocusNode();
  final FocusNode _lessAlignedFocus = FocusNode();

  @override
  void dispose() {
    _alignedController.dispose();
    _lessAlignedController.dispose();
    _alignedFocus.dispose();
    _lessAlignedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OriginPreferencesViewModel>();
    final alignedSuggestions = _filteredSuggestions(
      _alignedController.text,
      viewModel,
    );
    final lessSuggestions = _filteredSuggestions(
      _lessAlignedController.text,
      viewModel,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.topRight,
            child: SizedBox(height: 34),
          ),
          const SizedBox(height: 12),
          Text(
            'Origin Preferences',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customize country priorities to match your values',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 20),
          _PreferenceSection(
            label: 'Value aligned\ncountries',
            controller: _alignedController,
            focusNode: _alignedFocus,
            suggestions: alignedSuggestions,
            onQueryChanged: (_) => setState(() {}),
            onSelected: (country) async {
              await viewModel.addAligned(country);
              _alignedController.clear();
              _alignedFocus.requestFocus();
              setState(() {});
            },
            chips: viewModel.aligned,
            chipColor: _alignedGreen,
            onRemove: viewModel.removeAligned,
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1A497F), height: 24),
          const SizedBox(height: 12),
          _PreferenceSection(
            label: 'Less aligned\ncountries',
            controller: _lessAlignedController,
            focusNode: _lessAlignedFocus,
            suggestions: lessSuggestions,
            onQueryChanged: (_) => setState(() {}),
            onSelected: (country) async {
              await viewModel.addLessAligned(country);
              _lessAlignedController.clear();
              _lessAlignedFocus.requestFocus();
              setState(() {});
            },
            chips: viewModel.lessAligned,
            chipColor: _warningRed,
            onRemove: viewModel.removeLessAligned,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<String> _filteredSuggestions(
    String query,
    OriginPreferencesViewModel viewModel,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final selected = {
      ...viewModel.aligned.map((c) => OriginPreferences.normalize(c)),
      ...viewModel.lessAligned.map((c) => OriginPreferences.normalize(c)),
    };
    return OriginPreferences.allCountries
        .where((country) {
          final normalizedCountry = OriginPreferences.normalize(country);
          return normalizedCountry.contains(normalized) &&
              !selected.contains(normalizedCountry);
        })
        .take(5)
        .toList();
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.onQueryChanged,
    required this.onSelected,
    required this.chips,
    required this.chipColor,
    required this.onRemove,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> suggestions;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelected;
  final List<String> chips;
  final Color chipColor;
  final ValueChanged<String> onRemove;

  static const Color _primaryBlue = Color(0xFF052F61);
  static const Color _borderBlue = Color(0xFF1A497F);
  static const Color _hintBlue = Color(0xFF1A497F);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onQueryChanged,
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderBlue),
                        color: Colors.white,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final country = suggestions[index];
                          return InkWell(
                            onTap: () => onSelected(country),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(country),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFE5E9F2)),
                        itemCount: suggestions.length,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderBlue),
            color: Colors.white,
          ),
          child: chips.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'The countries you add\nwill appear here',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _hintBlue,
                          height: 1.35,
                        ),
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: chips
                      .map(
                        (country) => Chip(
                          label: Text(country),
                          labelStyle: TextStyle(
                            color: chipColor,
                            fontWeight: FontWeight.w600,
                          ),
                          deleteIcon:
                              Icon(Icons.close, size: 18, color: chipColor),
                          onDeleted: () => onRemove(country),
                          side: BorderSide(color: chipColor),
                          backgroundColor: Colors.white,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search...',
        prefixIcon: const Icon(Icons.search, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A497F)),
        ),
      ),
      onTap: () => focusNode.requestFocus(),
      onChanged: onChanged,
    );
  }
}
