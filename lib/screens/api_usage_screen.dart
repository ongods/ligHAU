import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_access.dart';
import '../services/api_usage_service.dart';
import '../widgets/app_header.dart';
import 'admin_login_screen.dart';

class ApiUsageScreen extends StatefulWidget {
  final ApiUsageService? service;
  const ApiUsageScreen({super.key, this.service});
  @override
  State<ApiUsageScreen> createState() => _ApiUsageScreenState();
}

class _ApiUsageScreenState extends State<ApiUsageScreen> {
  late final _service = widget.service ?? ApiUsageService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (AdminAccess.isAuthenticated) _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.load();
      if (mounted) setState(() => _data = data);
    } on ApiUsageException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the provider dashboard.')),
      );
    }
  }

  @override
  void dispose() {
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Widget _stat(String label, Object? value) => Container(
    constraints: const BoxConstraints(minHeight: 120),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${value ?? 'Unavailable'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );

  Widget _limit(
    String label,
    num used,
    dynamic limit, {
    bool estimate = false,
  }) {
    final known = limit is num && limit >= 0;
    final remaining = known ? (limit - used).clamp(0, limit) : null;
    final ratio = known && limit > 0
        ? (used / limit).clamp(0.0, 1.0).toDouble()
        : (known && used > 0 ? 1.0 : 0.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            known
                ? '$used / $limit used · $remaining remaining${estimate ? ' (estimate)' : ''}'
                : '$used observed · Quota unavailable',
          ),
          if (known) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              color: ratio >= 0.9 ? Theme.of(context).colorScheme.error : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );

  Widget _detailRow(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 16),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  String _dateLabel(Object? value) {
    final date = DateTime.tryParse('$value');
    return date == null
        ? 'Unavailable'
        : MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
  }

  List<Widget> _content(Map<String, dynamic> data) {
    final gemini = data['gemini'] as Map;
    final today = gemini['today'] as Map;
    final total = gemini['total'] as Map;
    final minute = gemini['minute'] as Map;
    final limits = gemini['limits'] as Map;
    final app = gemini['appLimit'] as Map;
    final map = data['maptiler'] as Map;
    final mapLimits = map['limits'] as Map;
    final updated = DateTime.tryParse(
      data['updatedAt'] as String? ?? '',
    )?.toLocal();
    return [
      Text(
        'Service overview',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      if (updated != null)
        Text(
          'Updated ${MaterialLocalizations.of(context).formatMediumDate(updated)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(updated))}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      const SizedBox(height: 24),
      _card('Gemini · Campus chatbot', [
        Text(
          '${gemini['model']} · ${gemini['configured'] == true ? 'Configured' : 'Not configured'}',
        ),
        const SizedBox(height: 12),
        Text('Today: ${gemini['day']} (Pacific time)'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 640 ? 4 : 2;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            final stats = [
              _stat('Requests attempted', today['requests']),
              _stat('Successful answers', today['successes']),
              _stat('Failed answers', today['failures']),
              _stat('Reported total tokens', today['totalTokens']),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats
                  .map((stat) => SizedBox(width: width, child: stat))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        if ((today['missingTokenReports'] as num) > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${today['missingTokenReports']} requests have no token report; token totals are incomplete.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        _UsageDetails(
          key: const ValueKey('token-usage-details'),
          title: 'Token breakdown & history',
          summary: 'Input, output and saved usage',
          icon: Icons.receipt_long_outlined,
          children: [
            _detailRow('Input tokens', today['inputTokens']),
            _detailRow('Output tokens', today['outputTokens']),
            _detailRow('Rate-limit errors (429)', today['rateLimited']),
            const Divider(height: 24),
            Text(
              'Usage history',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _detailRow('Tracked since', _dateLabel(gemini['since'])),
            _detailRow('Total requests', total['requests']),
            _detailRow('Reported total tokens', total['totalTokens']),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  gemini['persistent'] == true
                      ? Icons.cloud_done_outlined
                      : Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gemini['persistent'] == true
                        ? 'Usage counts are saved across backend restarts.'
                        : 'Usage counts are in memory; storage is unavailable.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ]),
      const SizedBox(height: 24),
      _card('Gemini quotas', [
        const Text(
          'Estimated remaining allowance for this campus app.',
          style: TextStyle(height: 1.6),
        ),
        _limit(
          'Requests · last 60 seconds',
          minute['requests'] as num,
          limits['rpm'],
          estimate: true,
        ),
        _limit(
          'Reported input tokens · last 60 seconds',
          minute['inputTokens'] as num,
          limits['tpm'],
          estimate: true,
        ),
        _limit(
          'Requests · today',
          today['requests'] as num,
          limits['rpd'],
          estimate: true,
        ),
        const Text(
          'Other apps sharing your project also consume quota. AI Studio shows current project usage and limits.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _open('https://aistudio.google.com/usage'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('View AI Studio usage & quotas'),
          ),
        ),
        const SizedBox(height: 12),
        _UsageDetails(
          key: const ValueKey('app-safety-details'),
          title: 'App safety limit',
          summary: '${app['used']} of ${app['limit']} requests in this window',
          icon: Icons.shield_outlined,
          children: [
            _limit(
              'App safety limit · 10-minute window',
              app['used'] as num,
              app['limit'],
            ),
            _detailRow(
              'Requests running',
              '${app['active']} / ${app['concurrency']}',
            ),
            if (app['perClient'] != null)
              _detailRow(
                'Per client / 10 minutes',
                '${app['perClient']} requests',
              ),
            if (app['daily'] != null)
              _detailRow('App daily cap', '${app['daily']} requests'),
            if (app['rpm'] != null)
              _detailRow('App minute cap', '${app['rpm']} requests'),
            if (app['queued'] != null)
              _detailRow(
                'Questions waiting',
                '${app['queued']} / ${app['queue']}',
              ),
            if (data['backend'] case final Map backend) ...[
              _detailRow('Backend server errors', '${backend['failures']}'),
              _detailRow('Rate-limited requests', '${backend['rateLimited']}'),
              _detailRow(
                'Recent response latency (p95)',
                '${backend['latencyP95Ms']} ms',
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'This is the app limit, separate from Gemini quota.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ]),
      const SizedBox(height: 24),
      _card('MapTiler · Campus map', [
        if (map['status'] == 'connected') ...[
          Text(
            'Account usage · ${map['since']} to ${map['until']} (current billing period)',
          ),
          _limit(
            'Map requests',
            map['requests'] as num,
            mapLimits['requests'],
            estimate: map['estimated'] == true,
          ),
          _limit(
            'Map sessions',
            map['sessions'] as num,
            mapLimits['sessions'],
            estimate: map['estimated'] == true,
          ),
          const Text(
            'Usage includes the whole MapTiler account. Quotas are configured plan allowances.',
          ),
          if (map['estimated'] == true)
            const Text('Includes provider estimates for the current day.'),
        ] else
          Text(
            map['status'] == 'not_configured'
                ? 'Account analytics is not connected. View usage and plan quota in MapTiler Cloud.'
                : 'MapTiler analytics is temporarily unavailable. View your account dashboard or retry.',
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _open('https://cloud.maptiler.com/account/'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('View MapTiler account'),
          ),
        ),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!AdminAccess.isAuthenticated) return const AdminLoginScreen();
    return Scaffold(
      appBar: AppHeader(
        title: 'API usage & quota',
        actions: [
          IconButton(
            tooltip: 'Refresh API usage',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PageBody(
        maxWidth: 900,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _loading ? null : _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_data != null) ..._content(_data!),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageDetails extends StatefulWidget {
  final String title;
  final String summary;
  final IconData icon;
  final List<Widget> children;
  const _UsageDetails({
    super.key,
    required this.title,
    required this.summary,
    required this.icon,
    required this.children,
  });

  @override
  State<_UsageDetails> createState() => _UsageDetailsState();
}

class _UsageDetailsState extends State<_UsageDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _expanded
            ? theme.colorScheme.surface
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline,
        ),
      ),
      child: ExpansionTile(
        onExpansionChanged: (value) => setState(() => _expanded = value),
        shape: shape,
        collapsedShape: shape,
        clipBehavior: Clip.antiAlias,
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: Icon(widget.icon, size: 22, color: theme.colorScheme.primary),
        title: Text(widget.title, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(widget.summary, style: theme.textTheme.bodySmall),
        ),
        trailing: Tooltip(
          message: _expanded ? 'Hide details' : 'Show details',
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        children: [const Divider(height: 16), ...widget.children],
      ),
    );
  }
}
