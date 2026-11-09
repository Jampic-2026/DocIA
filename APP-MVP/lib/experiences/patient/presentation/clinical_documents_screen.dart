import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/clinical_records/application/clinical_records_controller.dart';
import '../../../modules/clinical_records/domain/clinical_document.dart';
import '../../../modules/clinical_records/presentation/widgets/clinical_record_cards.dart';
import '../../../modules/files/application/files_controller.dart';

class ClinicalDocumentsScreen extends ConsumerWidget {
  const ClinicalDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos clínicos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: const _DocumentForm(),
            ),
          ),
        ),
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Agregar'),
      ),
      body: ref.watch(clinicalDocumentsProvider).when(
            loading: () => const AppLoadingState(message: 'Cargando documentos'),
            error: (error, _) => AppErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(clinicalDocumentsProvider),
            ),
            data: (documents) => documents.isEmpty
                ? const EmptyState(
                    icon: Icons.folder_copy_outlined,
                    title: 'Sin documentos clínicos',
                    message: 'Tus estudios e informes aparecerán aquí.',
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.refresh(clinicalDocumentsProvider.future),
                    child: AdaptivePage(
                      maxWidth: 920,
                      children: [
                        for (final document in documents)
                          ClinicalDocumentCard(
                            document: document,
                            onOpen: () => _openDocument(context, ref, document),
                          ),
                      ],
                    ),
                  ),
          ),
    );
  }
}

class _DocumentForm extends ConsumerStatefulWidget {
  const _DocumentForm();
  @override
  ConsumerState<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<_DocumentForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  PlatformFile? _file;
  String _type = 'laboratory';
  bool _restricted = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _file?.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un archivo válido.')));return;
    }
    setState(() => _saving = true);
    try {
      final stored=await ref.read(filesRepositoryProvider).upload(bytes:_file!.bytes!,fileName:_file!.name,category:'clinical-documents');
      await ref.read(clinicalRecordsRepositoryProvider).createDocument(
            CreateClinicalDocumentCommand(
              documentType: _type,
              fileUrl: stored.fileUrl,
              fileName: _name.text.trim().isEmpty?stored.fileName:_name.text.trim(),
              mimeType: stored.mimeType,
              isRestricted: _restricted,
            ),
          );
      ref.invalidate(clinicalDocumentsProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: ListView(shrinkWrap: true, children: [
            const Text('Agregar documento clínico', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            Text('Selecciona un archivo. Se almacenará de forma privada en Doc IA y quedará pendiente de validación.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo de documento'),
              items: const ['laboratory', 'imaging', 'report', 'prescription', 'other'].map((value) => DropdownMenuItem(value: value, child: Text(clinicalDocumentTypeLabel(value)))).toList(),
              onChanged: (value) => setState(() => _type = value ?? 'other'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(onPressed:_saving?null:_pickFile,icon:const Icon(Icons.upload_file_outlined),
              label:Text(_file==null?'Seleccionar archivo':_file!.name)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _name, label: 'Nombre del archivo'),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Documento restringido'),
              subtitle: const Text('Requiere autorización clínica para terceros.'),
              value: _restricted,
              onChanged: (value) => setState(() => _restricted = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _DocumentActions(
              saving: _saving,
              onCancel: () => Navigator.pop(context),
              onSave: _save,
            ),
          ]),
        ),
      );

  Future<void> _pickFile()async{final result=await FilePicker.platform.pickFiles(withData:true,type:FileType.custom,
    allowedExtensions:const['pdf','jpg','jpeg','png','webp','txt']);if(result==null)return;final file=result.files.single;
    setState(()=>_file=file);if(_name.text.trim().isEmpty)_name.text=file.name;}
}

class _DocumentActions extends StatelessWidget {
  const _DocumentActions({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppDialogActions(
      cancelLabel: 'Cancelar',
      confirmLabel: 'Guardar documento',
      busy: saving,
      busyLabel: 'Guardando...',
      confirmIcon: Icons.save_outlined,
      onCancel: onCancel,
      onConfirm: onSave,
    );
  }
}

Future<void> _openDocument(
  BuildContext context,
  WidgetRef ref,
  ClinicalDocument document,
) async {
  String fileUrl=document.fileUrl;
  try{if(Uri.parse(fileUrl).pathSegments.contains('files'))fileUrl=await ref.read(filesRepositoryProvider).accessUrl(fileUrl);}catch(error){
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString())));return;}
  final uri = Uri.tryParse(fileUrl);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento.')),
      );
    }
  }
}
