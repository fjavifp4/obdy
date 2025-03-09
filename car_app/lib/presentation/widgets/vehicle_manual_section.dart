import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../blocs/blocs.dart'; 

class VehicleManualSection extends StatefulWidget {
  final String vehicleId;

  const VehicleManualSection({
    super.key,
    required this.vehicleId,
  });

  @override
  State<VehicleManualSection> createState() => _VehicleManualSectionState();
}

class _VehicleManualSectionState extends State<VehicleManualSection> {
  bool _hasManual = false;
  bool _isLoading = true;
  String? _pdfPath;

  @override
  void initState() {
    super.initState();
    _checkManual();
  }

  void _checkManual() {
    if (!mounted) return;
    context.read<ManualBloc>().add(CheckManualExists(widget.vehicleId));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: BlocConsumer<ManualBloc, ManualState>(
        listener: (context, state) {
          if (state is ManualExists) {
            setState(() {
              _hasManual = state.exists;
              _isLoading = false;
            });
            
            if (_hasManual) {
              context.read<ManualBloc>().add(DownloadManual(widget.vehicleId));
            }
          } else if (state is ManualDownloaded) {
            _handleManualDownloaded(state.fileBytes);
            setState(() {
              _isLoading = false;
            });
          } else if (state is ManualError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            setState(() {
              _isLoading = false;
            });
          } else if (state is ManualLoading) {
            setState(() {
              _isLoading = true;
            });
          } else if (state is ManualDeleted) {
            setState(() {
              _pdfPath = null;
              _hasManual = false;
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Manual eliminado correctamente')),
            );
          } else if (state is ManualUpdated) {
            _checkManual(); // Recargar el manual
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Manual actualizado correctamente')),
            );
          }
        },
        builder: (context, state) {
          if (_isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando manual...'),
                ],
              ),
            );
          }

          if (_pdfPath != null) {
            return Stack(
              children: [
                PDFView(
                  filePath: _pdfPath!,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: false,
                  onError: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al cargar el PDF')),
                    );
                  },
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.update),
                            tooltip: 'Actualizar manual',
                            onPressed: () => _showUpdateConfirmationDialog(context),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            tooltip: 'Eliminar manual',
                            onPressed: () => _showDeleteConfirmationDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No hay manual disponible'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _uploadManual,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text('Subir Manual'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleManualDownloaded(List<int> bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/manual_${widget.vehicleId}.pdf');
      await file.writeAsBytes(bytes);
      
      if (mounted) {
        setState(() {
          _pdfPath = file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el manual: $e')),
        );
      }
    }
  }

  Future<void> _uploadManual() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (!mounted) return;
      
      if (result != null && result.files.first.bytes != null) {
        final file = result.files.first;
        context.read<ManualBloc>().add(
          UploadManual(
            vehicleId: widget.vehicleId,
            fileBytes: file.bytes!,
            filename: file.name,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar el archivo: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Text('Eliminar manual'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que quieres eliminar el manual? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              context.read<ManualBloc>().add(DeleteManual(widget.vehicleId));
              Navigator.pop(dialogContext);
              setState(() {
                _pdfPath = null;
                _hasManual = false;
              });
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateConfirmationDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.update),
            SizedBox(width: 8),
            Text('Actualizar manual'),
          ],
        ),
        content: const Text(
          '¿Quieres actualizar el manual actual con una nueva versión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _updateManual();
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateManual() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (!mounted) return;
      
      if (result != null && result.files.first.bytes != null) {
        final file = result.files.first;
        context.read<ManualBloc>().add(
          UpdateManual(
            vehicleId: widget.vehicleId,
            fileBytes: file.bytes!,
            filename: file.name,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar el archivo: $e')),
        );
      }
    }
  }
} 