// lib/screens/admin/accounting/import/admin_import_screen.dart
// VERSÃO ATUALIZADA: Delega a lógica de revisão para o `ImportReviewDialog`.

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'widgets/import_review_dialog.dart'; // <<< CORREÇÃO: Importa o novo dialog

class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({super.key});

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  // Variáveis para suportar web e mobile
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;

  String? _selectedFileName;
  String? _selectedFileExtension;
  int? _selectedFileSize;
  bool _isProcessing = false;

  // Tipos de arquivo suportados
  static const Map<String, String> supportedTypes = {
    'csv': 'Arquivo CSV (Planilha)',
    'xls': 'Excel 97-2003',
    'xlsx': 'Excel 2007+',
    'pdf': 'Documento PDF',
    'ofx': 'Open Financial Exchange',
    'qif': 'Quicken Interchange Format',
  };

  // Tamanho máximo do arquivo (50MB)
  static const int maxFileSize = 50 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23272A),
      appBar: AppBar(
        title: const Text('Importar Documentos'),
        backgroundColor: const Color(0xFF23272A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildSupportedTypesSection(),
            const SizedBox(height: 24),
            _buildFileSelectionSection(),
            const SizedBox(height: 24),
            if (_selectedFileName != null) ...[
              _buildFilePreviewSection(),
              const SizedBox(height: 24),
            ],
            if (_isProcessing) ...[
              _buildProcessingSection(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9147FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9147FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.cloud_upload,
              color: Color(0xFF9147FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Importação Automática',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Importe seus extratos bancários ou outros documentos financeiros para automatizar o lançamento de transações.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportedTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipos de Arquivo Suportados',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2F33),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: supportedTypes.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF36393F),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF9147FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFileSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecionar Arquivo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2F33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF9147FF).withOpacity(0.3),
              style: BorderStyle.solid,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: _isProcessing ? null : _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedFileName != null ? Icons.description : Icons.cloud_upload_outlined,
                  color: _selectedFileName != null ? const Color(0xFF9147FF) : Colors.white54,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFileName != null ? 'Arquivo Selecionado' : 'Clique para selecionar arquivo',
                  style: TextStyle(
                    color: _selectedFileName != null ? const Color(0xFF9147FF) : Colors.white70,
                    fontSize: 16,
                    fontWeight: _selectedFileName != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (_selectedFileName != null) const SizedBox(height: 4),
                if (_selectedFileName != null)
                  const Text(
                    'Ou clique para alterar',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePreviewSection() {
    final fileSizeKB = (_selectedFileSize ?? 0) / 1024;
    final fileSizeMB = fileSizeKB / 1024;
    final sizeText = fileSizeMB > 1 ? '${fileSizeMB.toStringAsFixed(1)} MB' : '${fileSizeKB.toStringAsFixed(0)} KB';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9147FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Arquivo Selecionado',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _clearSelection,
                icon: const Icon(Icons.close, color: Colors.white54),
                tooltip: 'Remover arquivo',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getFileTypeColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileTypeIcon(),
                  color: _getFileTypeColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFileName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _selectedFileExtension?.toUpperCase() ?? 'ARQUIVO',
                          style: const TextStyle(
                            color: Color(0xFF9147FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• $sizeText',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processImport,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isProcessing ? 'Processando...' : 'Processar Importação'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Processando Arquivo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            backgroundColor: Color(0xFF36393F),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9147FF)),
          ),
          SizedBox(height: 8),
          Text(
            'Analisando documento, por favor aguarde...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedTypes.keys.toList(),
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null) {
        final file = result.files.single;
        final fileSize = file.size;

        if (fileSize > maxFileSize) {
          _showMessage('Arquivo muito grande. Tamanho máximo: 50MB', Colors.orange);
          return;
        }

        setState(() {
          _selectedFileName = file.name;
          _selectedFileExtension = file.extension?.toLowerCase();
          _selectedFileSize = fileSize;

          if (kIsWeb) {
            _selectedFileBytes = file.bytes;
            _selectedFilePath = null;
          } else {
            _selectedFilePath = file.path;
            _selectedFileBytes = null;
          }
        });

        Logger.info('Arquivo selecionado: $_selectedFileName (${fileSize ~/ 1024} KB)');
      } else {
        Logger.info('Seleção de arquivo cancelada.');
      }
    } catch (e) {
      Logger.error('Erro ao selecionar arquivo: $e');
      _showMessage('Erro ao selecionar arquivo: ${e.toString()}', Colors.red);
    }
  }

  // <<< CORREÇÃO: Lógica de processamento agora chama o dialog de revisão >>>
  Future<void> _processImport() async {
    if (_selectedFilePath == null && _selectedFileBytes == null) {
      _showMessage('Por favor, selecione um arquivo para importar.', Colors.orange);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final accountingProvider = context.read<AccountingProvider>();
      
      final result = await accountingProvider.processDocument(
        filePath: _selectedFilePath,
        fileBytes: _selectedFileBytes,
        fileName: _selectedFileName!,
      );

      if (result['success'] == true) {
        final transactions = List<Map<String, dynamic>>.from(result['transactions'] ?? []);
        final summary = result['summary'];

        if (transactions.isNotEmpty) {
          // Abre o dialog de revisão
          final bool? importSuccess = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => ImportReviewDialog(
              initialTransactions: transactions,
              summary: summary,
            ),
          );

          if (importSuccess == true) {
            // Se o dialog retornar sucesso, limpa a seleção
            _clearSelection();
          }
        } else {
          _showMessage('Nenhuma transação encontrada no documento.', Colors.orange);
        }
      } else {
        _showMessage(result['error'] ?? 'Erro desconhecido no processamento.', Colors.red);
      }
    } catch (e) {
      Logger.error('Erro ao importar arquivo: $e');
      _showMessage('Erro ao importar arquivo: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileExtension = null;
      _selectedFileSize = null;
    });
  }

  Color _getFileTypeColor() {
    switch (_selectedFileExtension) {
      case 'csv':
        return Colors.green;
      case 'xlsx':
      case 'xls':
        return Colors.blue;
      case 'pdf':
        return Colors.red;
      case 'ofx':
      case 'qif':
        return Colors.orange;
      default:
        return const Color(0xFF9147FF);
    }
  }

  IconData _getFileTypeIcon() {
    switch (_selectedFileExtension) {
      case 'csv':
        return Icons.grid_on;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'ofx':
      case 'qif':
        return Icons.account_balance;
      default:
        return Icons.description;
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                      ? Icons.error
                      : Icons.warning,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
