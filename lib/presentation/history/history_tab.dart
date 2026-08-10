import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/history_item.dart';
import '../../domain/models/report_from_history.dart';
import '../common/scan_list_card.dart';
import '../common/stored_image.dart';
import '../common/tab_scaffold.dart';
import '../design/empty_state.dart';
import '../design/tokens.dart';
import '../report/product_report_view.dart';
import 'history_view_model.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key, this.onStartScan});

  /// Lets the empty state send the user somewhere instead of describing a
  /// dead end. The tab does not own the tab index, so the jump is handed down.
  final VoidCallback? onStartScan;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HistoryViewModel>();

    return TabScaffold(
      title: 'History',
      subtitle: 'Every scan, and how much of it was verified',
      action: viewModel.items.isEmpty
          ? null
          : DestructiveTextButton(
              label: 'Clear',
              onPressed: () => _confirmClearAll(context, viewModel),
            ),
      child: _HistoryBody(viewModel: viewModel, onStartScan: onStartScan),
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    HistoryViewModel viewModel,
  ) async {
    final count = viewModel.items.length;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete all $count scans?',
      message: 'History and its photos are removed from this device. This '
          'cannot be undone. Saved items are not affected.',
      confirmLabel: 'Delete all',
      cancelLabel: 'Keep them',
    );
    if (confirmed) {
      await viewModel.clearAll();
    }
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.viewModel, this.onStartScan});

  final HistoryViewModel viewModel;
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
        title: 'History could not be loaded',
        message: error,
      );
    }

    if (viewModel.items.isEmpty) {
      return EmptyState(
        icon: Icons.history,
        title: 'No scans yet',
        // Says what the list will hold and what makes it worth reading —
        // which is the badge, not the list.
        message: 'Products you scan are listed here, each marked with how '
            'much of it the app could actually verify.',
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
          background: const _DeleteBackground(),
          child: ScanListCard(
            report: item.toReport(),
            thumbnailBuilder: storedThumbnailBuilder(
              item.imagePath,
              item.originalImagePath,
            ),
            onTap: () => _open(context, item),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, HistoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => ProductReportView(
          report: item.toReport(),
          imageBuilder: (_) => storedImage(item.imagePath, item.originalImagePath),
          onClose: () => Navigator.of(routeContext).pop(),
        ),
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
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.negative,
        borderRadius: AppRadius.cardRadius,
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
    );
  }
}

