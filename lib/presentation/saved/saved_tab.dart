import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/report_from_history.dart';
import '../../domain/models/saved_product.dart';
import '../common/scan_list_card.dart';
import '../common/stored_image.dart';
import '../common/tab_scaffold.dart';
import '../design/empty_state.dart';
import '../design/tokens.dart';
import '../report/report_screen.dart';
import 'saved_products_view_model.dart';

class SavedTab extends StatelessWidget {
  const SavedTab({super.key, this.onStartScan});

  final VoidCallback? onStartScan;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SavedProductsViewModel>();

    return TabScaffold(
      title: 'Saved',
      subtitle: 'Scans you chose to keep',
      action: viewModel.items.isEmpty
          ? null
          : DestructiveTextButton(
              label: 'Clear',
              onPressed: () => _confirmClearAll(context, viewModel),
            ),
      child: _SavedBody(viewModel: viewModel, onStartScan: onStartScan),
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    SavedProductsViewModel viewModel,
  ) async {
    final count = viewModel.items.length;
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove all $count saved scans?',
      message: 'They are deleted from this device and cannot be recovered. '
          'History is not affected.',
      confirmLabel: 'Remove all',
      cancelLabel: 'Keep them',
    );
    if (confirmed) {
      await viewModel.clearAll();
    }
  }
}

class _SavedBody extends StatelessWidget {
  const _SavedBody({required this.viewModel, this.onStartScan});

  final SavedProductsViewModel viewModel;
  final VoidCallback? onStartScan;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    final error = viewModel.error;
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Saved items could not be loaded',
        message: error,
      );
    }

    if (viewModel.items.isEmpty) {
      return EmptyState(
        icon: Icons.bookmark_border,
        title: 'Nothing saved yet',
        // Names the exact control, because the bookmark lives on a screen the
        // user is not currently looking at.
        message: 'Tap the bookmark on a scan result to keep it here. Saved '
            'scans stay on this device.',
        actionLabel: onStartScan == null ? null : 'Scan a product',
        onAction: onStartScan,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: viewModel.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = viewModel.items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => viewModel.remove(item.id),
          background: const _RemoveBackground(),
          child: ScanListCard(
            report: item.toReport(),
            thumbnailBuilder: storedThumbnailBuilder(
              item.imagePath,
              item.originalImagePath,
            ),
            onTap: () => _open(context, item),
            trailing: IconButton(
              onPressed: () => viewModel.remove(item.id),
              icon: const Icon(Icons.bookmark, color: AppColors.brand),
              tooltip: 'Remove from saved',
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, SavedProduct item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => ReportScreen(
          report: item.toReport(),
          imageBuilder: (_) =>
              storedImage(item.imagePath, item.originalImagePath),
        ),
      ),
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.negative,
        borderRadius: AppRadius.cardRadius,
      ),
      child: const Icon(
        Icons.bookmark_remove_outlined,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

