import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/clay_button.dart';
import '../../../core/widgets/clay_card.dart';
import '../../../core/widgets/illustration_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../di/app_scope.dart';
import '../controllers/auth_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final register = widget.registration;
    final palette = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              register ? 'Create your account' : 'Welcome back',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    color: palette.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const IllustrationImage(
                            filename: 'login-signup.jpg',
                            size: 72,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClayCard(
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Log in'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Sign up'),
                                ),
                              ],
                              selected: {register},
                              onSelectionChanged: (value) => context.go(
                                value.single ? '/register' : '/login',
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (register) ...[
                              TextFormField(
                                controller: _name,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                ),
                                validator: (value) =>
                                    Validators.length(value, 'Name', 2, 80),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              autofillHints: const [AutofillHints.email],
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
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
                                register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: register
                                  ? Validators.password
                                  : (value) => (value ?? '').isEmpty
                                        ? 'Enter your password.'
                                        : null,
                              onFieldSubmitted: register
                                  ? null
                                  : (_) {
                                      if (widget.controller.state !=
                                          ViewState.loading) {
                                        _submit();
                                      }
                                    },
                            ),
                            if (register) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirm,
                                obscureText: _obscure,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm password',
                                ),
                                validator: (value) => value != _password.text
                                    ? 'Passwords must match.'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 16),
                            ListenableBuilder(
                              listenable: widget.controller,
                              builder: (context, child) {
                                final message =
                                    widget.controller.errorMessage ??
                                    widget.controller.sessionMessage;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (message != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Semantics(
                                          liveRegion: true,
                                          child: Text(message),
                                        ),
                                      ),
                                    ClayButton(
                                      label: register
                                          ? 'Create account'
                                          : 'Log in',
                                      onPressed: _submit,
                                      busy:
                                          widget.controller.state ==
                                          ViewState.loading,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!register && AppScope.of(context).config.useMock)
                    const ExpansionTile(
                      title: Text('Demo accounts'),
                      children: [
                        ListTile(
                          title: Text('Student'),
                          subtitle: Text('ali@student.com / Ali@1234'),
                        ),
                        ListTile(
                          title: Text('Department admin'),
                          subtitle: Text(
                            'library.admin@campus.com / Admin@1234',
                          ),
                        ),
                        ListTile(
                          title: Text('Super admin'),
                          subtitle: Text('super.admin@campus.com / Admin@1234'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
