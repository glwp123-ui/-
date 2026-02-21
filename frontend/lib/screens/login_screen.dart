import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/notion_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl   = TextEditingController();
  final _pwCtrl   = TextEditingController();
  final _formKey  = GlobalKey<FormState>();
  bool _obscure   = true;
  bool _loading   = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthProvider>();
    final err  = await auth.login(_idCtrl.text, _pwCtrl.text);

    if (mounted) {
      setState(() { _loading = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── 로고 영역
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: NotionTheme.accent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: NotionTheme.accent.withValues(alpha: 0.35),
                      blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Center(child: Text('🏥', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 20),
              const Text('song work',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: NotionTheme.textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              const Text('병원 업무 관리 시스템',
                style: TextStyle(fontSize: 13, color: NotionTheme.textSecondary)),
              const SizedBox(height: 40),

              // ── 로그인 카드
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('로그인',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: NotionTheme.textPrimary)),
                      const SizedBox(height: 22),

                      // 아이디
                      const _FieldLabel(text: '아이디'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _idCtrl,
                        decoration: _inputDeco(
                          hint: '아이디를 입력하세요',
                          icon: Icons.person_outline,
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                        validator: (v) => v == null || v.trim().isEmpty ? '아이디를 입력하세요' : null,
                      ),
                      const SizedBox(height: 16),

                      // 비밀번호
                      const _FieldLabel(text: '비밀번호'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pwCtrl,
                        obscureText: _obscure,
                        decoration: _inputDeco(
                          hint: '비밀번호를 입력하세요',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                              size: 18, color: NotionTheme.textSecondary),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        validator: (v) => v == null || v.trim().isEmpty ? '비밀번호를 입력하세요' : null,
                      ),
                      const SizedBox(height: 20),

                      // 에러 메시지
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(children: [
                            Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                              style: TextStyle(fontSize: 13, color: Colors.red.shade700))),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 로그인 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NotionTheme.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _loading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('로그인',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── 기본 계정 안내 (접을 수 있는)
              _DefaultAccountHint(),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: NotionTheme.textMuted, fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: NotionTheme.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F7F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NotionTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NotionTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NotionTheme.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NotionTheme.textPrimary));
}

// ── 기본 계정 안내 토글 위젯
class _DefaultAccountHint extends StatefulWidget {
  @override
  State<_DefaultAccountHint> createState() => _DefaultAccountHintState();
}

class _DefaultAccountHintState extends State<_DefaultAccountHint> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _show = !_show),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Text('기본 계정 안내', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                Icon(_show ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
          if (_show) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NotionTheme.border),
              ),
              child: Column(
                children: [
                  _AccountRow(role: '👑 마스터', id: 'master', pw: 'master1234'),
                  const Divider(height: 16),
                  _AccountRow(role: '🔑 관리자', id: 'admin', pw: 'admin1234'),
                  const Divider(height: 16),
                  _AccountRow(role: '👤 사용자', id: 'user1', pw: 'user1234'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String role, id, pw;
  const _AccountRow({required this.role, required this.id, required this.pw});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 80, child: Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: Text('ID: $id  /  PW: $pw',
        style: const TextStyle(fontSize: 12, color: NotionTheme.textSecondary, fontFamily: 'monospace'))),
    ],
  );
}
