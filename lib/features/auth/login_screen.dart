import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/errors/error_text.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/core/widgets/brand_widgets.dart';
import 'package:ganpati_mandal/core/widgets/otp_code_field.dart';

/// Email-OTP login. Step 1: enter the email -> the backend emails a 6-digit
/// code (only if an admin approved this address; the reply is identical either
/// way). Step 2: enter the code -> the backend verifies it and returns a
/// session token. There is no password and no registration.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _resendSeconds = 60; // the server enforces its own cooldown too

  final _emailKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (_busy || _cooldown > 0) return;
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    final l = ref.read(l10nProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestCode(_email.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeSent = true;
        _code.clear();
      });
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeError(l, e);
      });
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (!(_codeKey.currentState?.validate() ?? false)) return;
    final l = ref.read(l10nProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyAndSignIn(_email.text, _code.text);
      // AuthGate reacts to the new session by itself.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeError(l, e);
      });
    }
  }

  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _codeSent = false;
      _cooldown = 0;
      _error = null;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.royalBlue, AppTheme.blue],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () => ref.read(languageProvider.notifier).state =
                            l.isMarathi ? 'en' : 'mr',
                        child: Text(l.isMarathi ? 'English' : 'मराठी'),
                      ),
                    ),
                    const Center(child: BrandMark(size: 84, onDark: true)),
                    const SizedBox(height: 12),
                    Text(
                      l.t('app_name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _codeSent ? l.t('otp_enter_title') : l.t('sign_in'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (!_codeSent)
                              Form(
                                key: _emailKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email],
                                      textInputAction: TextInputAction.done,
                                      enabled: !_busy,
                                      onFieldSubmitted: (_) => _sendCode(),
                                      decoration: InputDecoration(
                                        labelText: l.t('email'),
                                        prefixIcon: const Icon(Icons.mail_outline),
                                      ),
                                      validator: (v) => _emailPattern.hasMatch((v ?? '').trim())
                                          ? null
                                          : l.t('v_email_invalid'),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      l.t('otp_members_only'),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              )
                            else
                              Form(
                                key: _codeKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '${l.t('otp_sent_hint')}\n${_email.text.trim()}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    OtpCodeField(
                                      controller: _code,
                                      enabled: !_busy,
                                      hasError: _error != null,
                                      validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())
                                          ? null
                                          : l.t('v_otp_invalid'),
                                      onChanged: (_) {
                                        if (_error != null) setState(() => _error = null);
                                      },
                                      onCompleted: (_) => _verify(),
                                    ),
                                  ],
                                ),
                              ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.error_outline, size: 18, color: scheme.error),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(color: scheme.onErrorContainer),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_codeSent ? l.t('otp_verify') : l.t('otp_send')),
                            ),
                            if (_codeSent) ...[
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: (_busy || _cooldown > 0) ? null : _sendCode,
                                child: Text(
                                  _cooldown > 0
                                      ? '${l.t('otp_resend_in')} $_cooldown ${l.t('seconds_short')}'
                                      : l.t('otp_resend'),
                                ),
                              ),
                              TextButton(
                                onPressed: _busy ? null : _changeEmail,
                                child: Text(l.t('otp_change_email')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
