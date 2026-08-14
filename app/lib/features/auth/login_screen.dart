import 'package:flutter/material.dart';

import '../../application/auth/auth_service.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/yukitas_snow_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authService,
    required this.onAuthenticated,
    super.key,
  });

  final AuthService authService;
  final VoidCallback onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isRegistration = false;
  String? _authError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'メールアドレスを入力してください';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return '正しいメールアドレスを入力してください';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'パスワードを入力してください';
    if (value.length < 6) return 'パスワードは6文字以上で入力してください';
    return null;
  }

  Future<void> _authenticate(Future<AuthUser> Function() action) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _authError = null;
    });
    try {
      await action();
      if (!mounted) return;
      widget.onAuthenticated();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() => _authError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _authError = '認証を完了できませんでした。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitEmail() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _authenticate(
      () =>
          _isRegistration
              ? widget.authService.registerWithEmail(
                email: _emailController.text,
                password: _passwordController.text,
              )
              : widget.authService.signInWithEmail(
                email: _emailController.text,
                password: _passwordController.text,
              ),
    );
  }

  Future<void> _submitGoogle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _authenticate(widget.authService.signInWithGoogle);
  }

  void _toggleRegistration() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isRegistration = !_isRegistration;
      _authError = null;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE5F7FF), YukitasColors.snow],
            stops: [0, 0.72],
          ),
        ),
        child: SafeArea(
          child: AutofillGroup(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _LoginTopBar(),
                        const SizedBox(height: 22),
                        const _WelcomeHero(),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              _isRegistration ? 'アカウント作成' : 'ログイン',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const Spacer(),
                            TextButton(
                              key: const Key('open-registration'),
                              onPressed:
                                  _isSubmitting ? null : _toggleRegistration,
                              child: Text(
                                _isRegistration ? 'ログインへ戻る' : 'はじめての方',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _LoginField(
                          key: const Key('login-email'),
                          controller: _emailController,
                          hintText: 'メールアドレス',
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 12),
                        _LoginField(
                          key: const Key('login-password'),
                          controller: _passwordController,
                          hintText: 'パスワード',
                          icon: Icons.verified_user_outlined,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          validator: _validatePassword,
                          onSubmitted: (_) => _submitEmail(),
                        ),
                        if (_authError != null) ...[
                          const SizedBox(height: 12),
                          _AuthErrorBanner(message: _authError!),
                        ],
                        const SizedBox(height: 16),
                        _isSubmitting
                            ? const _LoadingButton()
                            : GradientActionButton(
                              key: const Key('email-login'),
                              label: _isRegistration ? 'アカウントを作成' : 'ログイン',
                              height: 62,
                              onPressed: _submitEmail,
                            ),
                        if (!widget.authService.usesFirebase) ...[
                          const SizedBox(height: 12),
                          const _DemoModeNotice(),
                        ],
                        const SizedBox(height: 22),
                        const _OrDivider(),
                        const SizedBox(height: 20),
                        _GoogleButton(
                          enabled: !_isSubmitting,
                          onPressed: _submitGoogle,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          '2つの使い方',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Expanded(
                              child: _ModeDescriptionCard(
                                icon: Icons.home_outlined,
                                title: '雪かきを頼む',
                                subtitle: '依頼者モード',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _ModeDescriptionCard(
                                icon: Icons.emoji_events_outlined,
                                title: '雪かきをする',
                                subtitle: 'ワーカーモード',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginTopBar extends StatelessWidget {
  const _LoginTopBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [YukitasSnowLogo(size: 64), _SecurityBadge()],
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '安全なログイン',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xEFFFFFFF),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F075B9B),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.verified_user_outlined,
          color: YukitasColors.deep,
        ),
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 232,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xA6FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C075B9B),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/snow_town_hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFF1FAFF),
                  Color(0xE6ECF8FF),
                  Color(0x1AFFFFFF),
                ],
                stops: [0, 0.43, 0.78],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WELCOME',
                  style: TextStyle(
                    color: YukitasColors.action,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '地域の雪を、\nみんなの力で。',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 27,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '安全な依頼と作業を\nひとつのアカウントで',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: YukitasColors.muted,
                    height: 1.55,
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

class _LoginField extends StatelessWidget {
  const _LoginField({
    required super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.validator,
    required this.autofillHints,
    required this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: YukitasColors.muted),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 10),
          child: Icon(icon, color: YukitasColors.muted, size: 28),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 58),
        filled: true,
        fillColor: const Color(0xA6FFFFFF),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: YukitasColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: YukitasColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: YukitasColors.sky, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: YukitasColors.sos),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: YukitasColors.sos, width: 2),
        ),
      ),
    );
  }
}

class _LoadingButton extends StatelessWidget {
  const _LoadingButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [YukitasColors.sky, YukitasColors.action],
        ),
        borderRadius: BorderRadius.circular(19),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDF1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x66FF5B78)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: YukitasColors.sos,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9F2D46),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoModeNotice extends StatelessWidget {
  const _DemoModeNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: YukitasColors.muted,
        ),
        const SizedBox(width: 6),
        Text(
          'Firebase接続前のデモ認証です',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: YukitasColors.muted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'または',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: YukitasColors.muted),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Material(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        elevation: 2,
        shadowColor: const Color(0x26075B9B),
        child: InkWell(
          key: const Key('google-login'),
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'G',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: YukitasColors.deep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Googleで続ける',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: YukitasColors.deep,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeDescriptionCard extends StatelessWidget {
  const _ModeDescriptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 19),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: YukitasColors.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A075B9B),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 29, color: YukitasColors.ink),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: YukitasColors.muted),
          ),
        ],
      ),
    );
  }
}
