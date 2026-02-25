import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analysis/analysis_detail_screen.dart';
import 'history_view_model.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  static const Color _primaryBlue = Color(0xFF052F61);
  static const Color _secondaryBlue = Color(0xFF1A497F);

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HistoryViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              height: 34,
              child: FilledButton(
                onPressed: viewModel.items.isEmpty
                    ? null
                    : () => _confirmClearAll(context, viewModel),
                style: FilledButton.styleFrom(
                  backgroundColor: _secondaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Clear All'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'History',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'A record of your past analyses',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildBody(context, viewModel),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, HistoryViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.items.isEmpty) {
      return Center(
        child: Text(
          "You haven’t analysed any products yet.\nYour analysis history will appear here.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _primaryBlue,
                height: 1.35,
              ),
        ),
      );
    }

    return ListView.separated(
      itemCount: viewModel.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = viewModel.items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => viewModel.remove(item.id),
          background: const _DeleteBackground(),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalysisDetailScreen(
                    imagePath: item.imagePath,
                    fallbackImagePath: item.originalImagePath,
                    productName: item.productName,
                    companyName: item.companyName,
                    productionOrigin: item.productionOrigin,
                    hqCountry: item.hqCountry,
                    taxCountry: item.taxCountry,
                  ),
                ),
              );
            },
            child: _HistoryItemCard(
              imagePath: item.imagePath,
              fallbackImagePath: item.originalImagePath,
              productName: item.productName,
              companyName: item.companyName,
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    HistoryViewModel viewModel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _secondaryBlue, width: 1.2),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          title: Text(
            'Clear All',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _secondaryBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          content: Text(
            'Are you sure you want to clear all History?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _secondaryBlue,
                ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _secondaryBlue,
                      side: const BorderSide(color: _secondaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _secondaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Clear All'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (result == true) {
      await viewModel.clearAll();
    }
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({
    required this.imagePath,
    required this.fallbackImagePath,
    required this.productName,
    required this.companyName,
  });

  static const Color _borderBlue = Color(0xFF1A497F);

  final String imagePath;
  final String fallbackImagePath;
  final String productName;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final imageFile = File(imagePath);
    final fallbackFile = File(fallbackImagePath);
    final shouldUseFallback =
        imagePath.isEmpty || !imageFile.existsSync();
    final displayFile = shouldUseFallback ? fallbackFile : imageFile;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderBlue, width: 1.4),
        color: Colors.white,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 52,
              height: 52,
              color: const Color(0xFFEDEFF4),
              child: displayFile.path.isEmpty || !displayFile.existsSync()
                  ? const Icon(Icons.image, color: Color(0xFFB7C7D9))
                  : Image.file(displayFile, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFB11C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
    );
  }
}
