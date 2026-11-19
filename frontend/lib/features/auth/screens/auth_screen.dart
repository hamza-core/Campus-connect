import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/clay_button.dart';
import '../../../core/widgets/clay_card.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../di/app_scope.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_heading.dart';
import '../widgets/demo_accounts.dart';

final class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.controller,
    this.registration = false,
  });
  final AuthController controller;
  final bool registration;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

final class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (widget.registration) {
      widget.controller.register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
      );
    } else {
      widget.controller.signIn(_email.text.trim(), _password.text);
    }
  }

  void _switchTo(bool registration) {
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    context.go(
      Uri(
        path: registration ? '/register' : '/login',
        queryParameters: next == null ? null : {'next': next},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.registration;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeading(registration: register, compact: keyboardOpen),
            Transform.translate(
              offset: const Offset(0, -36),
              child: ResponsiveCenter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClayCard(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _form,
                          child: AutofillGroup(child: _fields(register)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: () => _switchTo(!register),
                          child: Text(
                            register
                                ? 'Already have an account? Log in'
                                : 'New here? Create an account',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 0, 8, 24),
                        child: Text(
                          'Department and campus administrators sign in with the account provided by the university.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF5F6B68),
                          ),
                        ),
                      ),
                      if (!register && AppScope.of(context).config.useMock)
                        const DemoAccounts(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fields(bool register) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AuthToggle(registration: register, onChanged: _switchTo),
      const SizedBox(height: 18),
      if (register) ...[
        TextFormField(
          controller: _name,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
            hintText: 'Full name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) => Validators.length(value, 'Name', 2, 80),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
      ],
      TextFormField(
        controller: _email,
        autofillHints: const [AutofillHints.email],
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          hintText: 'Email',
          prefixIcon: Icon(Icons.mail_outline),
        ),
        validator: Validators.email,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _password,
        obscureText: _obscure,
        autofillHints: [
          register ? AutofillHints.newPassword : AutofillHints.password,
        ],
        decoration: InputDecoration(
          hintText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        textInputAction: register ? TextInputAction.next : TextInputAction.done,
        validator: register
            ? Validators.password
            : (value) => (value ?? '').isEmpty ? 'Enter your password.' : null,
        onFieldSubmitted: register
            ? null
            : (_) {
                if (widget.controller.state != ViewState.loading) _submit();
              },
      ),
      if (register) PasswordChecklist(controller: _password),
      if (register) ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirm,
          obscureText: _obscure,
          decoration: const InputDecoration(
            hintText: 'Confirm password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            if (widget.controller.state != ViewState.loading) _submit();
          },
          validator: (value) =>
              value != _password.text ? 'Passwords must match.' : null,
        ),
      ],
      const SizedBox(height: 18),
      ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          final message =
              widget.controller.errorMessage ??
              widget.controller.sessionMessage;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE0E0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ),
                ),
              ClayButton(
                label: register ? 'Create account' : 'Log in',
                onPressed: _submit,
                busy: widget.controller.state == ViewState.loading,
              ),
            ],
          );
        },
      ),
    ],
  );
}
