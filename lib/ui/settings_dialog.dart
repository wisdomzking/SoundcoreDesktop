import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/speech_provider.dart';
import '../state/desktop_controller.dart';
import '../theme/app_theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late SttProvider _provider;
  late String _language;
  late TextEditingController _sonioxKey;
  late TextEditingController _mossKey;
  bool _obscureSoniox = true;
  bool _obscureMoss = true;

  @override
  void initState() {
    super.initState();
    final c = context.read<DesktopController>();
    _provider = c.provider;
    _language = c.language;
    _sonioxKey = TextEditingController(text: c.sonioxKey ?? '');
    _mossKey = TextEditingController(text: c.mossKey ?? '');
  }

  @override
  void dispose() {
    _sonioxKey.dispose();
    _mossKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    '转写设置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text('转写引擎',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<SttProvider>(
                segments: const [
                  ButtonSegment(
                    value: SttProvider.moss,
                    label: Text('MOSS Pro'),
                    icon: Icon(Icons.auto_awesome_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: SttProvider.soniox,
                    label: Text('Soniox'),
                    icon: Icon(Icons.graphic_eq_rounded, size: 16),
                  ),
                ],
                selected: {_provider},
                onSelectionChanged: (v) => setState(() => _provider = v.first),
              ),
              const SizedBox(height: 20),

              const Text('识别语言',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('自动检测')),
                  DropdownMenuItem(value: 'zh', child: Text('中文')),
                  DropdownMenuItem(value: 'en', child: Text('英语')),
                  DropdownMenuItem(value: 'ja', child: Text('日语')),
                  DropdownMenuItem(value: 'ko', child: Text('韩语')),
                ],
                onChanged: (v) => setState(() => _language = v ?? 'auto'),
              ),
              const SizedBox(height: 20),

              const Text('MOSS Pro API Key',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _mossKey,
                obscureText: _obscureMoss,
                decoration: InputDecoration(
                  hintText: 'api.mosi.cn 的 API Key',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureMoss
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () =>
                        setState(() => _obscureMoss = !_obscureMoss),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Soniox API Key',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _sonioxKey,
                obscureText: _obscureSoniox,
                decoration: InputDecoration(
                  hintText: 'api.soniox.com 的 API Key',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureSoniox
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () =>
                        setState(() => _obscureSoniox = !_obscureSoniox),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'API Key 仅保存在本地配置文件，不会上传到任何第三方服务器。',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: () async {
                  await context.read<DesktopController>().saveSettings(
                        provider: _provider,
                        language: _language,
                        sonioxKey: _sonioxKey.text,
                        mossKey: _mossKey.text,
                      );
                  if (mounted) Navigator.pop(context);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
