import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../utils/notion_theme.dart';

// ── 병원 전용 이모지 세트 (카테고리별 구분)
const _kHospitalEmojis = [
  // 진료과
  '🫀', '🫁', '🧠', '🦷', '👁️', '🦴', '🩺', '🔬',
  // 치료·처치
  '💉', '💊', '🩹', '🩻', '🩸', '🧬', '🔪', '🚑',
  // 행정·지원
  '🏥', '🚨', '📋', '📊', '💼', '🗂️', '📞', '🧹',
  // 기타 의료
  '🌡️', '⚕️', '🧪', '🫙', '🩼', '👨‍⚕️', '👩‍⚕️', '🏋️',
];

// 카테고리 라벨
const _kEmojiCategories = ['진료과', '치료·처치', '행정·지원', '기타'];
const _kEmojiPerCategory = 8;

void showDeptFormSheet(BuildContext context, AppProvider provider,
    [Department? existing]) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => _DeptFormSheet(provider: provider, existing: existing),
  );
}

class _DeptFormSheet extends StatefulWidget {
  final AppProvider provider;
  final Department? existing;
  const _DeptFormSheet({required this.provider, this.existing});

  @override
  State<_DeptFormSheet> createState() => _DeptFormSheetState();
}

class _DeptFormSheetState extends State<_DeptFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _managerCtrl;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _managerCtrl =
        TextEditingController(text: widget.existing?.managerName ?? '');
    _emoji = widget.existing?.emoji ?? '🏥';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _managerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NotionTheme.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Text(_emoji,
                        style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Text(
                isEdit ? '부서 수정' : '새 부서 추가',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: NotionTheme.textPrimary),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                color: NotionTheme.textSecondary,
              ),
            ]),

            const SizedBox(height: 20),

            // ── 아이콘 선택 (병원 전용 카테고리)
            const Text('부서 아이콘',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NotionTheme.textSecondary,
                    letterSpacing: 0.3)),
            const SizedBox(height: 10),

            // 카테고리별 이모지 그리드
            ...List.generate(_kEmojiCategories.length, (catIdx) {
              final start = catIdx * _kEmojiPerCategory;
              final emojis = _kHospitalEmojis.sublist(
                  start, start + _kEmojiPerCategory);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, top: 4),
                    child: Text(
                      _kEmojiCategories[catIdx],
                      style: const TextStyle(
                          fontSize: 10,
                          color: NotionTheme.textMuted,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Row(
                    children: emojis
                        .map((e) => GestureDetector(
                              onTap: () => setState(() => _emoji = e),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 38,
                                height: 38,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: _emoji == e
                                      ? NotionTheme.accentLight
                                      : NotionTheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _emoji == e
                                        ? NotionTheme.accent
                                        : NotionTheme.border,
                                    width: _emoji == e ? 1.5 : 1,
                                  ),
                                ),
                                child: Center(
                                    child: Text(e,
                                        style: const TextStyle(fontSize: 18))),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                ],
              );
            }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // ── 부서 이름
            _FieldLabel('부서 이름 *'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: '예: 내과, 외과, 간호팀, 원무팀...'),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),

            // ── 담당자
            _FieldLabel('담당 책임자'),
            const SizedBox(height: 6),
            TextField(
              controller: _managerCtrl,
              decoration: const InputDecoration(
                  hintText: '담당 의사·수간호사 이름 (선택)'),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),

            // ── 설명
            _FieldLabel('부서 설명'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              decoration:
                  const InputDecoration(hintText: '부서 역할 및 담당 업무 (선택)'),
              style: const TextStyle(fontSize: 15),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // ── 저장 버튼
            Row(
              children: [
                // 삭제 버튼 (수정 모드)
                if (isEdit) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // 삭제 확인은 사이드바에서 처리
                    },
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    label: const Text('삭제',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NotionTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (_nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('부서 이름을 입력해주세요'),
                                backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (isEdit) {
                          widget.existing!.name = _nameCtrl.text.trim();
                          widget.existing!.emoji = _emoji;
                          widget.existing!.description =
                              _descCtrl.text.trim();
                          widget.existing!.managerName =
                              _managerCtrl.text.trim().isEmpty
                                  ? null
                                  : _managerCtrl.text.trim();
                          await widget.provider
                              .updateDepartment(widget.existing!);
                        } else {
                          await widget.provider.addDepartment(
                            name: _nameCtrl.text.trim(),
                            emoji: _emoji,
                            description: _descCtrl.text.trim(),
                            managerName: _managerCtrl.text.trim().isEmpty
                                ? null
                                : _managerCtrl.text.trim(),
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(
                        isEdit ? '수정 완료' : '부서 추가',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: NotionTheme.textSecondary,
            letterSpacing: 0.3),
      );
}
