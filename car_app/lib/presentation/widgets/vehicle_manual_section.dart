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
    return BlocConsumer<ManualBloc, ManualState>(
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
          return PDFView(
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
          );
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No hay manual disponible'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _uploadManual(),
                child: const Text('Subir Manual'),
              ),
            ],
          ),
        );
      },
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
} 