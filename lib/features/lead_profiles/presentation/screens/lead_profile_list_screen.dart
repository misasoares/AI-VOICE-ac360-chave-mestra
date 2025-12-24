import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lead_profile_list_provider.dart';
import '../providers/lead_profile_repository_provider.dart';
import '../../domain/entities/lead_profile.dart';
import 'create_lead_profile_screen.dart';

class LeadProfileListScreen extends ConsumerWidget {
  const LeadProfileListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(leadProfileListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfis de Leads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (context) => const CreateLeadProfileScreen(),
                ),
              )
                  .then((_) {
                // Refresh list when coming back
                // ignore: unused_local_variable
                final result = ref.refresh(leadProfileListProvider);
              });
            },
            tooltip: 'Criar Perfil de Lead',
          ),
        ],
      ),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Nenhum perfil criado ainda.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(
                          builder: (context) => const CreateLeadProfileScreen(),
                        ),
                      )
                          .then((_) {
                        // ignore: unused_local_variable
                        final result = ref.refresh(leadProfileListProvider);
                      });
                    },
                    child: const Text('Criar Perfil de Lead'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(profile.name),
                  subtitle:
                      Text(profile.answers['role'] ?? 'Sem cargo definido'),
                  onTap: () => _showProfileDetails(context, profile),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () =>
                        _showDeleteConfirmation(context, ref, profile),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Erro ao carregar perfis: $err')),
      ),
    );
  }

  void _showProfileDetails(BuildContext context, LeadProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(profile.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...profile.answers.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: '${e.key}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: e.value),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    LeadProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Perfil'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tem certeza que deseja excluir este perfil?'),
                const SizedBox(height: 16),
                Text(
                  'Nome: ${profile.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Características:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...profile.answers.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                    child: Text('${e.key}: ${e.value}'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(leadProfileRepositoryProvider).deleteProfile(profile.id);
      // Refresh the list to remove the deleted item
      // ignore: unused_result
      ref.refresh(leadProfileListProvider);
    }
  }
}
