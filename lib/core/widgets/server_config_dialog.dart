import 'package:flutter/material.dart';
import '../../app_store.dart';
import '../theme/app_theme.dart';
import 'empiran_components.dart';

/// Interactive modal dialog allowing users to switch between
/// Local Development and Cloud backend servers, test latency/health,
/// or specify a custom backend endpoint.
class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key, required this.store});

  final AppStore store;

  static const String localPreset = 'http://localhost:5186/api/v1';
  static const String cloudPreset = 'https://empiran-api.runasp.net/api/v1';

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  bool _testing = false;
  Map<String, dynamic>? _healthResult;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.store.currentApiUrl);
    _testConnection(widget.store.currentApiUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection(String url) async {
    setState(() {
      _testing = true;
      _healthResult = null;
    });

    final res = await widget.store.api.checkHealth(url);
    if (mounted) {
      setState(() {
        _testing = false;
        _healthResult = res;
      });
    }
  }

  Future<void> _applyUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return;

    await widget.store.setApiUrl(clean);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected API URL updated to $clean'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentActive = widget.store.currentApiUrl;
    final inputUrl = _urlController.text.trim();

    final isLocalSelected = inputUrl == ServerConfigDialog.localPreset;
    final isCloudSelected = inputUrl == ServerConfigDialog.cloudPreset;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: const Icon(Icons.dns_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Backend Server Settings',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Choose between local development or cloud production',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Presets
              const Text(
                'Select Environment Preset',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  // Local Preset Card
                  Expanded(
                    child: _PresetCard(
                      title: 'Local Dev Server',
                      subtitle: 'http://localhost:5186',
                      badge: 'ASP.NET Core',
                      icon: Icons.computer_rounded,
                      isSelected: isLocalSelected,
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _urlController.text = ServerConfigDialog.localPreset;
                        });
                        _testConnection(ServerConfigDialog.localPreset);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Cloud Preset Card
                  Expanded(
                    child: _PresetCard(
                      title: 'Cloud Production',
                      subtitle: 'empiran-api.runasp.net',
                      badge: 'Live Cloud',
                      icon: Icons.cloud_done_rounded,
                      isSelected: isCloudSelected,
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _urlController.text = ServerConfigDialog.cloudPreset;
                        });
                        _testConnection(ServerConfigDialog.cloudPreset);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Custom URL Input
              EmpiranTextField(
                controller: _urlController,
                label: 'API Endpoint URL',
                hint: 'http://localhost:5186/api/v1',
                prefixIcon: Icons.link_rounded,
                onChanged: (_) {
                  setState(() {
                    _healthResult = null;
                  });
                },
                suffixIcon: IconButton(
                  tooltip: 'Test Connection',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _testing
                      ? null
                      : () => _testConnection(_urlController.text),
                ),
              ),
              const SizedBox(height: 16),

              // Live Status / Health Box
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _healthResult == null
                      ? (isDark
                          ? AppColors.darkSurfaceContainer
                          : AppColors.lightSurfaceContainer)
                      : (_healthResult!['healthy'] == true
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(
                    color: _healthResult == null
                        ? (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder)
                        : (_healthResult!['healthy'] == true
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.error.withValues(alpha: 0.4)),
                  ),
                ),
                child: Row(
                  children: [
                    if (_testing) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Pinging server endpoint...',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ] else if (_healthResult != null) ...[
                      Icon(
                        _healthResult!['healthy'] == true
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _healthResult!['healthy'] == true
                            ? AppColors.success
                            : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _healthResult!['healthy'] == true
                                  ? 'Endpoint Online (${_healthResult!['environment'] ?? 'Live'})'
                                  : 'Connection Failed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _healthResult!['healthy'] == true
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                            Text(
                              _healthResult!['message']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_healthResult!['latencyMs'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_healthResult!['latencyMs']} ms',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ] else ...[
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Click "Test Connection" to check endpoint availability.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  EmpiranButton(
                    label: _testing ? 'Testing...' : 'Test Connection',
                    icon: Icons.network_check_rounded,
                    variant: EmpiranButtonVariant.secondary,
                    isLoading: _testing,
                    onPressed: () => _testConnection(_urlController.text),
                  ),
                  const SizedBox(width: 10),
                  EmpiranButton(
                    label: inputUrl == currentActive
                        ? 'Saved & Active'
                        : 'Save & Connect',
                    icon: Icons.check_rounded,
                    onPressed: inputUrl.isEmpty
                        ? null
                        : () => _applyUrl(_urlController.text),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark
                  ? AppColors.darkSurfaceContainer
                  : AppColors.lightSurfaceContainer),
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white12 : Colors.black12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
