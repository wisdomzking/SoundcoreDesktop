import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/desktop_controller.dart' show DesktopController, JobStatus, TranscriptionJob;
import '../theme/app_theme.dart';
import 'settings_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _importFiles(BuildContext context) async {
    const group = XTypeGroup(
      label: '音频文件',
      extensions: ['opus', 'ogg', 'wav', 'mp3', 'm4a', 'aac', 'flac'],
    );
    final files = await openFiles(acceptedTypeGroups: [group]);
    if (files.isEmpty) return;
    if (!context.mounted) return;
    await context.read<DesktopController>().importFiles(
          files.map((f) => File(f.path)).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopController>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('安克录音豆 · 桌面转写'),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.canTranscribe
                  ? AppColors.mint.withValues(alpha: 0.12)
                  : AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  c.canTranscribe ? Icons.check_circle : Icons.warning_amber,
                  size: 14,
                  color: c.canTranscribe ? AppColors.mint : AppColors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  c.canTranscribe ? '${c.provider.label} 已就绪' : '未配置 API Key',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.canTranscribe ? AppColors.mint : AppColors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: c.jobs.isEmpty
          ? _EmptyState(onImport: () => _importFiles(context))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 340,
                  child: _FileList(
                    jobs: c.jobs,
                    playingId: c.playingJobId,
                    onImport: () => _importFiles(context),
                    onTranscribe: (job) => c.transcribe(job),
                    onSelect: (_) {},
                    onRemove: (job) => c.removeJob(job.id),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _DetailPane(controller: c)),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.audiotrack_rounded,
                size: 48, color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          const Text(
            '导入录音，开始离线转写',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            '支持 .opus / .ogg / .wav / .mp3 等格式\n'
            '通过 MOSS Pro 或 Soniox AI 生成带说话人分离的转写文本',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.file_open_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text('选择音频文件'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
            child: const Text('先配置 API Key'),
          ),
        ],
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({
    required this.jobs,
    required this.playingId,
    required this.onImport,
    required this.onTranscribe,
    required this.onSelect,
    required this.onRemove,
  });

  final List<TranscriptionJob> jobs;
  final String? playingId;
  final VoidCallback onImport;
  final Function(TranscriptionJob) onTranscribe;
  final Function(TranscriptionJob) onSelect;
  final Function(TranscriptionJob) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('录音文件',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: '导入',
                icon: const Icon(Icons.add_rounded, size: 20),
                onPressed: onImport,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: jobs.length,
            itemBuilder: (context, idx) {
              final job = jobs[idx];
              return _JobTile(
                job: job,
                isPlaying: job.id == playingId,
                onTranscribe: () => onTranscribe(job),
                onRemove: () => onRemove(job),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({
    required this.job,
    required this.isPlaying,
    required this.onTranscribe,
    required this.onRemove,
  });

  final TranscriptionJob job;
  final bool isPlaying;
  final VoidCallback onTranscribe;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    switch (job.status) {
      case JobStatus.done:
        statusColor = AppColors.mint;
        statusIcon = Icons.check_circle_rounded;
      case JobStatus.failed:
        statusColor = AppColors.coral;
        statusIcon = Icons.error_rounded;
      case JobStatus.preparing:
      case JobStatus.uploading:
      case JobStatus.processing:
        statusColor = AppColors.accent;
        statusIcon = Icons.sync_rounded;
      case JobStatus.idle:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(
            isPlaying ? Icons.play_arrow_rounded : statusIcon,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          job.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          job.status == JobStatus.idle
              ? '等待转写'
              : job.progress ??
                  (job.status == JobStatus.done
                      ? '转写完成'
                      : job.error ?? '处理中'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: job.status == JobStatus.failed
                ? AppColors.coral
                : AppColors.textMuted,
          ),
        ),
        trailing: job.status == JobStatus.done
            ? IconButton(
                tooltip: '重新转写',
                icon: const Icon(Icons.replay_rounded, size: 18),
                onPressed: onTranscribe,
              )
            : job.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: '开始转写',
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    onPressed: onTranscribe,
                  ),
        onLongPress: onRemove,
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.controller});
  final DesktopController controller;

  @override
  Widget build(BuildContext context) {
    final doneJobs = controller.jobs.where((j) => j.isDone).toList();
    if (doneJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 56, color: AppColors.border),
            const SizedBox(height: 16),
            const Text(
              '转写结果将显示在这里',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            const Text(
              '在左侧选择文件，点击 ✨ 开始转写',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: doneJobs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: doneJobs
                .map((j) => Tab(
                      text: j.fileName.length > 20
                          ? '${j.fileName.substring(0, 20)}…'
                          : j.fileName,
                    ))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              children: doneJobs.map((j) => _TranscriptView(job: j)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptView extends StatelessWidget {
  const _TranscriptView({required this.job});
  final TranscriptionJob job;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  job.fileName,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: '播放',
                icon: const Icon(Icons.play_circle_outline_rounded),
                onPressed: () => context.read<DesktopController>().play(job),
              ),
              IconButton(
                tooltip: '复制文本',
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: () {
                  Share.share(job.text ?? '');
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: SelectableText(
              job.text ?? '',
              style: const TextStyle(
                fontSize: 15,
                height: 1.8,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
