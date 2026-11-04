import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../common/actions.dart';
import '../common/layout.dart';
import 'hero_section.dart' show linkIcon;

const _roles = {
  'phd': 'Prospective PhD scholar',
  'msc': 'Prospective MSc scholar',
  'collaborator': 'Research collaborator',
  'institution': 'Institution / organisation',
  'media': 'Media',
  'other': 'Other',
};

class ContactSection extends ConsumerWidget {
  const ContactSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = screenSize(context);
    return SectionShell(
      alt: true,
      child: AsyncBlock(
        value: ref.watch(profileProvider),
        builder: (p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            eyebrow: 'Contact',
            title: 'Get in touch',
            subtitle: 'For supervision, research collaboration, editorial matters at the Nepalese Journal of Statistics, '
                'or institutional enquiries.',
          ),
          if (size.isCompact) ...[
            _ContactInfo(profile: p),
            const SizedBox(height: 24),
            _ContactForm(profile: p),
          ] else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: _ContactInfo(profile: p)),
              const SizedBox(width: 32),
              Expanded(flex: 7, child: _ContactForm(profile: p)),
            ]),
        ]),
      ),
    );
  }
}

class _ContactInfo extends StatelessWidget {
  const _ContactInfo({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget row(IconData icon, String label, String value, {VoidCallback? onTap, VoidCallback? onCopy, bool mono = false}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: p.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: context.text.labelSmall?.copyWith(color: p.muted)),
                if (mono)
                  // Never break an email/phone mid-token; shrink to fit instead.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, maxLines: 1, softWrap: false, style: context.mono(size: 13)),
                  )
                else
                  Text(value, style: context.text.bodyMedium?.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (onCopy != null) IconButton(tooltip: 'Copy', onPressed: onCopy, icon: Icon(Icons.content_copy, size: 16, color: p.muted)),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final e in profile.emails)
              row(Icons.mail_outline, e.endsWith('.edu.np') ? 'Institutional email' : 'Email', e,
                  mono: true,
                  onTap: () => openLink(context, mailto(e)),
                  onCopy: () => copyToClipboard(context, e, 'Email address copied')),
            if (profile.mobile case final m?)
              row(Icons.smartphone_outlined, 'Mobile', m,
                  mono: true,
                  onTap: () => openLink(context, Uri(scheme: 'tel', path: m.replaceAll('-', ''))),
                  onCopy: () => copyToClipboard(context, m, 'Mobile number copied')),
            if (profile.phone.isNotEmpty)
              row(Icons.call_outlined, 'Department phone', profile.phone,
                  mono: true, onTap: () => openLink(context, Uri(scheme: 'tel', path: profile.phone.replaceAll('-', '')))),
            row(Icons.home_outlined, 'Address', profile.address),
            if (profile.officeAddress case final o?) row(Icons.account_balance_outlined, 'Office', o),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Academic profiles', style: context.text.titleLarge),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final l in profile.links)
                ActionChip(
                  avatar: Icon(linkIcon(l.kind), size: 16, color: p.ink),
                  label: Text(l.label),
                  onPressed: () => openLink(context, Uri.parse(l.url)),
                ),
            ]),
            if (profile.link('orcid')?.handle case final orcid?) ...[
              const SizedBox(height: 16),
              Row(children: [
                Text('ORCID ', style: context.text.labelLarge?.copyWith(color: p.muted)),
                SelectableText(orcid, style: context.mono(size: 13, color: const Color(0xFFA6CE39), weight: FontWeight.w700)),
              ]),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _org = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _role = 'phd';
  bool _sending = false;
  Map<String, String> _serverErrors = {};

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    for (final c in [_name, _email, _org, _subject, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _len(String? v, int min, int max, String what) {
    final n = (v ?? '').trim().length;
    if (n < min) return min <= 1 ? '$what is required' : '$what must be at least $min characters';
    if (n > max) return '$what must be at most $max characters';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    final body = {
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'role': _role,
      'organization': _org.text.trim(),
      'subject': _subject.text.trim(),
      'message': _message.text.trim(),
      'website': '',
    };
    try {
      await ref.read(repositoryProvider).sendContact(body);
      if (!mounted) return;
      _form.currentState!.reset();
      for (final c in [_name, _email, _org, _subject, _message]) {
        c.clear();
      }
      showToast(context, 'Thank you. Your message has been received.');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fields.isNotEmpty) {
        setState(() => _serverErrors = e.fields);
        _form.currentState!.validate();
        showToast(context, 'Please correct the highlighted fields.', error: true);
      } else {
        final to = widget.profile.emails.first;
        showToast(
          context,
          e.unreachable
              ? 'The message service is offline. You can email Prof. Shrestha directly instead.'
              : e.message,
          error: true,
          action: SnackBarAction(
            label: 'Email instead',
            textColor: Brand.goldLight,
            onPressed: () => openLink(
              context,
              mailto(to,
                  subject: body['subject'],
                  body: '${body['message']}\n\n${body['name']}\n${body['organization']}\n(${_roles[_role]})'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = screenSize(context).isMobile;
    String? server(String f) => _serverErrors[f];

    final name = TextFormField(
      controller: _name,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Full name *'),
      validator: (v) => server('name') ?? _len(v, 2, 120, 'Name'),
    );
    final email = TextFormField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Email *'),
      validator: (v) => server('email') ?? (_emailRe.hasMatch((v ?? '').trim()) ? null : 'Enter a valid email address'),
    );
    final role = DropdownButtonFormField<String>(
      initialValue: _role,
      decoration: const InputDecoration(labelText: 'I am a… *'),
      items: [for (final e in _roles.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) => setState(() => _role = v ?? 'other'),
      validator: (_) => server('role'),
    );
    final org = TextFormField(
      controller: _org,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Institution / organisation'),
      validator: (v) => server('organization') ?? _len(v, 0, 200, 'Organisation'),
    );

    Widget pair(Widget a, Widget b) => mobile
        ? Column(children: [a, const SizedBox(height: 16), b])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ]);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(mobile ? 20 : 28),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Send a message', style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text('Prospective scholars: include your intended degree, research interest and a short outline.',
                style: context.text.bodyMedium),
            const SizedBox(height: 22),
            pair(name, email),
            const SizedBox(height: 16),
            pair(role, org),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subject,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Subject *'),
              validator: (v) => server('subject') ?? _len(v, 3, 200, 'Subject'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _message,
              minLines: 5,
              maxLines: 10,
              maxLength: 5000,
              decoration: const InputDecoration(labelText: 'Message *', alignLabelWithHint: true),
              validator: (v) => server('message') ?? _len(v, 20, 5000, 'Message'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'Sending…' : 'Send message'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
