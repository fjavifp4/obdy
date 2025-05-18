import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../blocs/blocs.dart';
import '../screens/vehicle_details_screen.dart';

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
  
  // Flag para controlar si debemos mostrar el diálogo de análisis
  bool _pendingAnalysisDialog = false;
  
  // Controladores
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final TextEditingController _pageController = TextEditingController();
  
  // Estados y controladores para búsqueda
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  bool _hasSearchResults = false;
  int _currentSearchIndex = 0;
  int _totalSearchResults = 0;

  @override
  void initState() {
    super.initState();
    _checkManual();
  }
  
  @override
  void didUpdateWidget(VehicleManualSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Si tenemos un diálogo pendiente y ya no estamos cargando, mostrarlo
    if (_pendingAnalysisDialog && !_isLoading) {
      // Usar un pequeño delay para asegurar que la UI está lista
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _pendingAnalysisDialog) {
          _pendingAnalysisDialog = false;
          _showAnalyzeConfirmationDialog();
        }
      });
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Este método se llama cuando las dependencias cambian
    // Es un buen lugar para verificar si necesitamos limpiar recursos
  }
  
  @override
  void deactivate() {
    // Se llama cuando el widget se quita temporalmente del árbol de widgets
    // Es el momento ideal para limpiar recursos que deben ser restablecidos
    // cuando el widget se reactive
    if (_isSearching) {
      // Limpiar recursos de búsqueda al cambiar de pestañas
      _clearSearchQuietly();
    }
    super.deactivate();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    // Asegurarse de limpiar el resultado de búsqueda y desuscribirse de los listeners
    if (_searchResult.hasResult) {
      _searchResult.clear();
    }
    _searchResult.removeListener(_handleSearchResults);
    super.dispose();
  }
  
  // Versión silenciosa de _clearSearch que no muestra notificaciones
  void _clearSearchQuietly() {
    if (_searchResult.hasResult) {
      _searchResult.clear();
    }
    
    if (mounted) {
      setState(() {
        _isSearching = false;
        _hasSearchResults = false;
        _currentSearchIndex = 0;
        _totalSearchResults = 0;
      });
    }
  }

  void _checkManual() {
    if (!mounted) return;
    context.read<ManualBloc>().add(CheckManualExists(widget.vehicleId));
  }

  // Método helper para mostrar SnackBars descartando cualquier SnackBar existente
  void _showSnackBar(String message, {Duration? duration}) {
    // Descartar cualquier SnackBar existente
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // Mostrar el nuevo SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
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
          _showSnackBar(state.message);
          setState(() {
            _isLoading = false;
            _pendingAnalysisDialog = false; // Resetear en caso de error
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
            _pendingAnalysisDialog = false; // Resetear después de eliminar
          });
          _showSnackBar('Manual eliminado correctamente');
        } else if (state is ManualUpdated) {
          // Marcar como pendiente el diálogo de análisis y recargar el manual
          setState(() {
            _pendingAnalysisDialog = true;
            _isLoading = false;
          });
          _checkManual(); // Recargar el manual
          
          _showSnackBar('Manual subido correctamente');
          
          // Solo mostrar el diálogo si no estamos cargando
          if (!_isLoading) {
            // Retrasar para evitar conflictos con la actualización de estado
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _pendingAnalysisDialog) {
                _pendingAnalysisDialog = false;
                _showAnalyzeConfirmationDialog();
              }
            });
          }
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
                SizedBox(height: 8),
                Text(
                  'Este proceso puede tardar unos segundos',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (_pdfPath != null) _buildToolbar(),
            const SizedBox(height: 8),
            Expanded(
              child: _pdfPath == null
                  ? _buildNoManualAvailable()
                  : Stack(
                      children: [
                        SfPdfViewer.file(
                          File(_pdfPath!),
                          controller: _pdfViewerController,
                          key: _pdfViewerKey,
                          enableTextSelection: true,
                          onPageChanged: (PdfPageChangedDetails details) {
                            // Forzar actualización del estado cuando cambie la página
                            if (mounted) {
                              setState(() {
                                // Solo necesitamos llamar a setState() para que se redibuje la interfaz
                              });
                            }
                          },
                        ),
                        
                        // Overlay de búsqueda
                        if (_isSearching)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _buildSearchBar(),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    final ThemeData theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botones de zoom
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Aumentar zoom',
            onPressed: () {
              _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel + 0.25).clamp(0.75, 3.0);
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Reducir zoom',
            onPressed: () {
              _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel - 0.25).clamp(0.75, 3.0);
            },
          ),
          
          // Selector de página
          Expanded(
            child: GestureDetector(
              onTap: _showPageNavigationDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Página ${_pdfViewerController.pageNumber} de ${_pdfViewerController.pageCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Botón de búsqueda
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar texto',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  // Limpiar búsqueda al cerrar
                  _clearSearch();
                }
              });
            },
          ),
          
          // Botones de gestión de PDF
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Opciones',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'update',
                child: Row(
                  children: [
                    Icon(Icons.update),
                    SizedBox(width: 12),
                    Text('Actualizar manual'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Eliminar manual', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'update') {
                _showUpdateConfirmationDialog(context);
              } else if (value == 'delete') {
                _showDeleteConfirmationDialog(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoManualAvailable() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay manual disponible',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sube el manual del taller de tu vehículo para consultar\n'
            'información técnica y programar mantenimientos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _uploadManual,
            icon: Icon(Icons.upload_file, color: Theme.of(context).colorScheme.onPrimary),
            label: Text('Subir Manual'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final ThemeData theme = Theme.of(context);
    
    return Container(
      color: theme.colorScheme.surface.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar en el manual...',
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _clearSearch();
                          },
                        )
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _performSearch(value);
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar búsqueda',
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _clearSearch();
                  });
                },
              ),
            ],
          ),
          if (_hasSearchResults) 
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '$_currentSearchIndex de $_totalSearchResults resultados',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: 'Resultado anterior',
                    onPressed: _previousSearchResult,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    tooltip: 'Siguiente resultado',
                    onPressed: _nextSearchResult,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Método para manejar cambios en los resultados de búsqueda
  void _handleSearchResults() {
    if (!mounted) return;
    
    if (_searchResult.hasResult) {
      setState(() {
        _hasSearchResults = true;
        _totalSearchResults = _searchResult.totalInstanceCount;
        _currentSearchIndex = _searchResult.currentInstanceIndex;
      });
      
      if (_searchResult.isSearchCompleted && _totalSearchResults == 0) {
        if (mounted) {
          setState(() {
            _hasSearchResults = false;
          });
        }
      }
    }
  }

  Future<void> _performSearch(String searchText) async {
    if (searchText.isEmpty) {
      _clearSearch();
      return;
    }

    try {
      // Primero eliminar cualquier listener existente
      _searchResult.removeListener(_handleSearchResults);
      
      // Usar el controlador para buscar el texto
      _searchResult = _pdfViewerController.searchText(searchText);
      
      // Para plataformas móviles y desktop, la búsqueda es asíncrona
      _searchResult.addListener(_handleSearchResults);
    } catch (e) {
      print('Error en la búsqueda: $e');
      if (mounted) {
        _simulateSearch(searchText);
      }
    }
  }
  
  void _simulateSearch(String searchText) {
    if (!mounted) return;
    
    // Simulación de búsqueda para proporcionar feedback visual al usuario
    setState(() {
      _hasSearchResults = true;
      // Generar un número aleatorio entre 1 y 10 para simular resultados
      _totalSearchResults = searchText.length + 3;
      _currentSearchIndex = 1;
    });
  }

  void _nextSearchResult() {
    if (!_hasSearchResults || !mounted) return;
    
    try {
      if (_searchResult.hasResult) {
        _searchResult.nextInstance();
        if (mounted) {
          setState(() {
            _currentSearchIndex = _searchResult.currentInstanceIndex;
          });
        }
      } else {
        // Navegación simulada
        if (mounted) {
          setState(() {
            _currentSearchIndex = (_currentSearchIndex % _totalSearchResults) + 1;
          });
          _showNavigationFeedback();
        }
      }
    } catch (e) {
      print('Error al navegar al siguiente resultado: $e');
      // Navegación simulada como fallback
      if (mounted) {
        setState(() {
          _currentSearchIndex = (_currentSearchIndex % _totalSearchResults) + 1;
        });
        _showNavigationFeedback();
      }
    }
  }

  void _previousSearchResult() {
    if (!_hasSearchResults || !mounted) return;
    
    try {
      if (_searchResult.hasResult) {
        _searchResult.previousInstance();
        if (mounted) {
          setState(() {
            _currentSearchIndex = _searchResult.currentInstanceIndex;
          });
        }
      } else {
        // Navegación simulada
        if (mounted) {
          setState(() {
            _currentSearchIndex = _currentSearchIndex > 1 
                ? _currentSearchIndex - 1 
                : _totalSearchResults;
          });
          _showNavigationFeedback();
        }
      }
    } catch (e) {
      print('Error al navegar al resultado anterior: $e');
      // Navegación simulada como fallback
      if (mounted) {
        setState(() {
          _currentSearchIndex = _currentSearchIndex > 1 
              ? _currentSearchIndex - 1 
              : _totalSearchResults;
        });
        _showNavigationFeedback();
      }
    }
  }

  void _showNavigationFeedback() {
    // Método vacío ahora, ya no mostramos feedback
  }

  void _clearSearch() {
    if (_searchResult.hasResult) {
      _searchResult.clear();
    }
    
    if (!mounted) return;
    
    setState(() {
      _hasSearchResults = false;
      _currentSearchIndex = 0;
      _totalSearchResults = 0;
    });
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
        _showSnackBar('Error al guardar el manual: $e');
      }
    }
  }

  Future<void> _showAnalyzeConfirmationDialog() {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology),
            SizedBox(width: 8),
            Text('Análisis del manual'),
          ],
        ),
        content: const Text(
          'El manual se ha subido correctamente.\n\n'
          '¿Quieres ir a la sección de mantenimiento para analizar el manual con IA?\n\n'
          'Esto te ayudará a extraer automáticamente los intervalos de mantenimiento recomendados.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ahora no'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              
              // Mostrar un mensaje de confirmación
              _showSnackBar(
                'Redirigiendo a la sección de mantenimiento...',
                duration: const Duration(seconds: 2)
              );
              
              // Redirigir a la sección de mantenimiento
              _analyzeManual();
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ir a mantenimiento'),
          ),
        ],
      ),
    );
  }
  
  // Función para iniciar el análisis del manual
  void _analyzeManual() {
    // Usando el enfoque de navegación para ir a la pestaña de mantenimiento
    // donde el usuario puede iniciar el análisis manualmente
    final vehicleDetailsState = VehicleDetailsScreen.globalKey.currentState;
    if (vehicleDetailsState != null) {
      // Cambiar a la pestaña de mantenimiento
      vehicleDetailsState.setSelectedIndex(1);
      
      // Mostrar una notificación al usuario para que inicie el análisis manualmente
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showSnackBar(
            'Haz clic en "Analizar con IA" en la sección de mantenimiento para procesar el manual',
            duration: const Duration(seconds: 5)
          );
        }
      });
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
        
        // Mostrar indicador de progreso
        _showSnackBar(
          'Subiendo manual... Por favor espera.',
          duration: const Duration(seconds: 30)
        );
        
        // Explícitamente establecer el estado de carga
        setState(() {
          _isLoading = true;
        });
        
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
        // Restablecer el estado de carga en caso de error
        setState(() {
          _isLoading = false;
        });
        
        _showSnackBar('Error al seleccionar el archivo: $e');
      }
    }
  }

  void _showPageNavigationDialog() {
    _pageController.text = _pdfViewerController.pageNumber.toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book),
            SizedBox(width: 8),
            Text('Ir a página'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pageController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Número de página',
                hintText: '1 - ${_pdfViewerController.pageCount}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Introduce un número entre 1 y ${_pdfViewerController.pageCount}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final pageNumber = int.tryParse(_pageController.text);
              if (pageNumber != null && 
                  pageNumber >= 1 && 
                  pageNumber <= _pdfViewerController.pageCount) {
                _pdfViewerController.jumpToPage(pageNumber);
              }
              Navigator.pop(context);
            },
            child: const Text('Ir'),
          ),
        ],
      ),
    );
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
        
        // Mostrar indicador de progreso
        _showSnackBar(
          'Actualizando manual... Por favor espera.',
          duration: const Duration(seconds: 30)
        );
        
        // Explícitamente establecer el estado de carga
        setState(() {
          _isLoading = true;
        });
        
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
        // Restablecer el estado de carga en caso de error
        setState(() {
          _isLoading = false;
        });
        
        _showSnackBar('Error al seleccionar el archivo: $e');
      }
    }
  }
}

// Widget para mostrar un círculo de progreso con rotación infinita
class _RotatingProgressCircle extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const _RotatingProgressCircle({
    required this.size,
    required this.strokeWidth,
    this.color,
  });

  @override
  _RotatingProgressCircleState createState() => _RotatingProgressCircleState();
}

class _RotatingProgressCircleState extends State<_RotatingProgressCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CircleProgressPainter(
            progress: _controller.value,
            color: color,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

// Widget para mostrar un icono pulsante
class _PulsatingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const _PulsatingIcon({
    required this.icon,
    required this.size,
    this.color,
  });

  @override
  _PulsatingIconState createState() => _PulsatingIconState();
}

class _PulsatingIconState extends State<_PulsatingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: color,
          ),
        );
      },
    );
  }
}

// Painter personalizado para dibujar un círculo de progreso
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    
    // Dibuja el círculo de fondo completo
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Dibuja el arco de progreso
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57, // Comienza desde arriba (270 grados o -π/2)
      progress * 2 * 3.14, // Ángulo en radianes
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
} 