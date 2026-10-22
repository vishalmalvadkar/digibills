import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../../models/mou_template_model.dart';
import '../../services/mou_service.dart';
import '../../theme/app_colors.dart';
import 'mou_edit_screen.dart';

class MouTemplatesScreen extends StatelessWidget {
  const MouTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MOU Templates'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<List<MouTemplateModel>>(
        stream: MouService().streamTemplates(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final templates = snapshot.data ?? [];
          
          if (templates.isEmpty) {
             // Trigger default creation if empty
             MouService().getActiveTemplate(); 
             return const Center(child: Text('Loading default...'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: template.isActive 
                      ? const BorderSide(color: AppColors.primary, width: 2) 
                      : BorderSide.none,
                ),
                child: ListTile(
                  title: Text(
                    'Version: ${template.version}', // e.g. v1.0
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Updated: ${DateFormat('dd MMM yyyy, HH:mm').format(template.updatedAt)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (template.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text('ACTIVE', style: TextStyle(
                            color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12
                          )),
                        )
                      else 
                        TextButton(
                          onPressed: () => _confirmPublish(context, template),
                          child: const Text('Publish'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => MouEditScreen(template: template))
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
           context, 
           MaterialPageRoute(builder: (_) => const MouEditScreen())
        ),
      ),
    );
  }

  void _confirmPublish(BuildContext context, MouTemplateModel template) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Publish Version?'),
        content: Text('This will make version ${template.version} the active MOU for all new clients. Existing active template will be deactivated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await MouService().publishTemplate(template.id);
            }, 
            child: const Text('Publish')
          ),
        ],
      ),
    );
  }
}
