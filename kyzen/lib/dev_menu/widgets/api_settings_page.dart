import 'package:material_ui/material_ui.dart';
import '../../api/environment_service.dart';

class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  final _service = EnvironmentService.instance;
  List<EnvironmentConfig> _envs = [];
  String? _activeEnvName;
  bool _isLoading = true;
  bool _showForm = false;

  final _nameController = TextEditingController();
  final _titleIdController = TextEditingController();
  final _secretController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleIdController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final envs = await _service.getEnvironments();
    final active = await _service.getActiveEnvironment();
    if (!mounted) return;
    setState(() {
      _envs = envs;
      _activeEnvName = active.name;
      _isLoading = false;
    });
  }

  Future<void> _selectEnvironment(String name) async {
    await _service.setActiveEnvironment(name);
    if (!mounted) return;
    setState(() => _activeEnvName = name);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Environment Changed',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Switched to "$name". App restart required.',
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(milliseconds: 1700),
      ),
    );
  }

  Future<void> _addEnvironment() async {
    if (!_formKey.currentState!.validate()) return;

    final env = EnvironmentConfig(
      name: _nameController.text.trim(),
      titleId: _titleIdController.text.trim(),
      sharedSecret: _secretController.text.trim(),
    );

    await _service.addEnvironment(env);

    _nameController.clear();
    _titleIdController.clear();
    _secretController.clear();

    if (!mounted) return;

    final updatedEnvs = await _service.getEnvironments();

    setState(() {
      _envs = updatedEnvs;
      _showForm = false;
    });
  }

  Future<void> _deleteEnvironment(String name) async {
    await _service.deleteEnvironment(name);
    if (!mounted) return;

    final updatedEnvs = await _service.getEnvironments();
    final active = await _service.getActiveEnvironment();

    setState(() {
      _envs = updatedEnvs;
      _activeEnvName = active.name;
    });
  }

  Widget _buildEnvTile(EnvironmentConfig env) {
    final isActive = _activeEnvName == env.name;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isActive ? Icons.check_circle : Icons.circle_outlined,
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 24,
          ),
        ),
        title: Text(
          env.name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            env.titleId,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: env.isDefault
            ? const SizedBox(width: 48)
            : IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error.withValues(alpha: 0.7),
                ),
                onPressed: () => _deleteEnvironment(env.name),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
        onTap: () => _selectEnvironment(env.name),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('API Environments')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerLowest,
                  ],
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _buildSectionHeader(
                    'Environments',
                    subtitle: '${_envs.length + 1} total',
                  ),

                  _buildEnvTile(EnvironmentService.defaultEnv),
                  ..._envs.map(_buildEnvTile),

                  const SizedBox(height: 8),

                  if (_showForm) ...[
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'New Environment',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Environment Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Name is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _titleIdController,
                                decoration: InputDecoration(
                                  labelText: 'Title ID',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Title ID is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _secretController,
                                decoration: InputDecoration(
                                  labelText: 'Shared Secret',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Secret is required'
                                    : null,
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          setState(() => _showForm = false),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: FilledButton(
                                      onPressed: _addEnvironment,
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add, size: 18),
                                          SizedBox(width: 8),
                                          Text('Add Environment'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showForm = true),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add New Environment'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
