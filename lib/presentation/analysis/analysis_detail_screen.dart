import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../preferences/origin_preferences_view_model.dart';

class AnalysisDetailScreen extends StatelessWidget {
  const AnalysisDetailScreen({
    super.key,
    required this.imagePath,
    required this.fallbackImagePath,
    required this.productName,
    required this.companyName,
    required this.productionOrigin,
    required this.hqCountry,
    required this.taxCountry,
  });

  final String imagePath;
  final String fallbackImagePath;
  final String productName;
  final String companyName;
  final String? productionOrigin;
  final String? hqCountry;
  final String? taxCountry;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OriginPreferencesViewModel(),
      child: Builder(
        builder: (context) {
          final imageFile = File(imagePath);
          final fallbackFile = File(fallbackImagePath);
          final shouldUseFallback =
              imagePath.isEmpty || !imageFile.existsSync();
          final displayFile = shouldUseFallback ? fallbackFile : imageFile;
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF052F61),
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analysed Image',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF052F61),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI-generated insights from your latest image',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Transform.translate(
                      offset: const Offset(-24, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 96,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A497F),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 180,
                                height: 180,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: displayFile.path.isEmpty ||
                                          !displayFile.existsSync()
                                      ? const SizedBox.shrink()
                                      : Image.file(
                                          displayFile,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _InfoRow(
                      label: 'Product:',
                      value: productName.isEmpty ? 'Not found' : productName,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Company:',
                      value: companyName.isEmpty ? 'Not found' : companyName,
                    ),
                    const SizedBox(height: 16),
                    _InfoSplitRow(
                      label: 'Production',
                      value: productionOrigin ?? 'Not found',
                      preferences: context.watch<OriginPreferencesViewModel>(),
                    ),
                    const Divider(height: 24),
                    _InfoSplitRow(
                      label: 'Tax & Profit',
                      value: taxCountry ?? 'Not found',
                      preferences: context.watch<OriginPreferencesViewModel>(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
            ),
        children: [
          TextSpan(
            text: '$label\n',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF052F61),
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _InfoSplitRow extends StatelessWidget {
  const _InfoSplitRow({
    required this.label,
    required this.value,
    required this.preferences,
  });

  final String label;
  final String value;
  final OriginPreferencesViewModel preferences;

  @override
  Widget build(BuildContext context) {
    final lines = _parseCountryLines(value, preferences);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF052F61),
                ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _lineColor(line.status),
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Column(
          children: lines
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: line.status == null
                      ? const SizedBox(height: 20, width: 20)
                      : Icon(
                          line.status == _CountryStatus.aligned
                              ? Icons.verified
                              : Icons.warning_amber_rounded,
                          size: 20,
                          color: line.status == _CountryStatus.aligned
                              ? const Color(0xFF1A7F4A)
                              : const Color(0xFFB11C1C),
                        ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

enum _CountryStatus { aligned, misaligned }

class _CountryLine {
  const _CountryLine({required this.text, this.status});

  final String text;
  final _CountryStatus? status;
}

List<_CountryLine> _parseCountryLines(
  String value,
  OriginPreferencesViewModel preferences,
) {
  final parts = value
      .split(RegExp(r'[\n,]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return [const _CountryLine(text: 'Not found')];
  }
  return parts
      .map((part) {
        final lower = part.toLowerCase();
        if (lower.contains('other countries')) {
          return _CountryLine(text: part, status: null);
        }
        if (preferences.matchesAligned(part)) {
          return _CountryLine(text: part, status: _CountryStatus.aligned);
        }
        if (preferences.matchesLessAligned(part)) {
          return _CountryLine(text: part, status: _CountryStatus.misaligned);
        }
        return _CountryLine(text: part, status: null);
      })
      .toList();
}

Color _lineColor(_CountryStatus? status) {
  if (status == _CountryStatus.aligned) {
    return const Color(0xFF1A7F4A);
  }
  if (status == _CountryStatus.misaligned) {
    return const Color(0xFFB11C1C);
  }
  return Colors.black87;
}
