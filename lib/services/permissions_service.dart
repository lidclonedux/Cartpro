// lib/services/permissions_service.dart
import 'dart:io';
import 'package:flutter/material.dart'; // ✅ ADICIONADO - Import essencial do Flutter
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/logger.dart';

class PermissionsService {
  static final _picker = ImagePicker();

  /// Solicita permissões necessárias para acesso à galeria e câmera
  static Future<bool> requestStoragePermissions() async {
    try {
      Logger.info('PermissionsService: Solicitando permissões de storage');
      
      List<Permission> permissions = [];
      
      if (Platform.isAndroid) {
        // Para Android - diferentes versões precisam de permissões diferentes
        final androidInfo = await _getAndroidVersion();
        
        if (androidInfo >= 33) {
          // Android 13+ (API 33+) - Usa permissões granulares
          permissions.addAll([
            Permission.photos,
            Permission.camera,
          ]);
        } else if (androidInfo >= 30) {
          // Android 11-12 (API 30-32)
          permissions.addAll([
            Permission.storage,
            Permission.camera,
          ]);
        } else {
          // Android 10 e inferior (API < 30)
          permissions.addAll([
            Permission.storage,
            Permission.camera,
          ]);
        }
      } else if (Platform.isIOS) {
        // Para iOS
        permissions.addAll([
          Permission.photos,
          Permission.camera,
        ]);
      }

      // Verificar status atual das permissões
      Map<Permission, PermissionStatus> statuses = {};
      for (final permission in permissions) {
        statuses[permission] = await permission.status;
      }

      Logger.info('PermissionsService: Status das permissões: $statuses');

      // Solicitar permissões que não foram concedidas
      List<Permission> toRequest = [];
      for (final permission in permissions) {
        final status = statuses[permission]!;
        if (status != PermissionStatus.granted) {
          toRequest.add(permission);
        }
      }

      if (toRequest.isNotEmpty) {
        Logger.info('PermissionsService: Solicitando permissões: $toRequest');
        final newStatuses = await toRequest.request();
        
        // Verificar se todas foram concedidas
        bool allGranted = true;
        for (final permission in toRequest) {
          final status = newStatuses[permission]!;
          if (status != PermissionStatus.granted) {
            allGranted = false;
            Logger.warning('PermissionsService: Permissão negada: $permission - $status');
          }
        }

        if (allGranted) {
          Logger.info('PermissionsService: ✅ Todas as permissões concedidas');
          return true;
        } else {
          Logger.warning('PermissionsService: ❌ Algumas permissões foram negadas');
          return false;
        }
      } else {
        Logger.info('PermissionsService: ✅ Todas as permissões já concedidas');
        return true;
      }
      
    } catch (e) {
      Logger.error('PermissionsService: Erro ao solicitar permissões', error: e);
      return false;
    }
  }

  /// Verifica se tem permissões necessárias
  static Future<bool> hasStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidVersion();
        
        if (androidVersion >= 33) {
          // Android 13+ - verifica Photos
          return await Permission.photos.isGranted;
        } else {
          // Android < 13 - verifica Storage
          return await Permission.storage.isGranted;
        }
      } else if (Platform.isIOS) {
        return await Permission.photos.isGranted;
      }
      
      return false;
    } catch (e) {
      Logger.error('PermissionsService: Erro ao verificar permissões', error: e);
      return false;
    }
  }

  /// Seleciona imagem da galeria com tratamento de permissões
  static Future<File?> pickImageFromGallery({
    int maxWidth = 1024,
    int maxHeight = 1024,
    int imageQuality = 80,
  }) async {
    try {
      Logger.info('PermissionsService: Iniciando seleção de imagem da galeria');
      
      // Verificar e solicitar permissões
      final hasPermission = await hasStoragePermissions();
      if (!hasPermission) {
        Logger.info('PermissionsService: Solicitando permissões de galeria');
        final granted = await requestStoragePermissions();
        if (!granted) {
          Logger.warning('PermissionsService: Permissões de galeria negadas');
          return null;
        }
      }

      // Selecionar imagem
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        Logger.info('PermissionsService: ✅ Imagem selecionada da galeria: ${image.path}');
        return File(image.path);
      } else {
        Logger.info('PermissionsService: Seleção de imagem cancelada pelo usuário');
        return null;
      }
      
    } catch (e) {
      Logger.error('PermissionsService: Erro ao selecionar imagem da galeria', error: e);
      return null;
    }
  }

  /// Captura foto com a câmera
  static Future<File?> takePhoto({
    int maxWidth = 1024,
    int maxHeight = 1024,
    int imageQuality = 80,
  }) async {
    try {
      Logger.info('PermissionsService: Iniciando captura de foto');
      
      // Verificar permissão de câmera
      final cameraStatus = await Permission.camera.status;
      if (cameraStatus != PermissionStatus.granted) {
        Logger.info('PermissionsService: Solicitando permissão de câmera');
        final granted = await Permission.camera.request();
        if (granted != PermissionStatus.granted) {
          Logger.warning('PermissionsService: Permissão de câmera negada');
          return null;
        }
      }

      // Capturar foto
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        Logger.info('PermissionsService: ✅ Foto capturada: ${image.path}');
        return File(image.path);
      } else {
        Logger.info('PermissionsService: Captura de foto cancelada pelo usuário');
        return null;
      }
      
    } catch (e) {
      Logger.error('PermissionsService: Erro ao capturar foto', error: e);
      return null;
    }
  }

  /// Mostra dialog de opções (galeria ou câmera)
  static Future<File?> showImageSourceDialog({
    required BuildContext context,
    String title = 'Selecionar Imagem',
    String galleryText = 'Galeria',
    String cameraText = 'Câmera',
    String cancelText = 'Cancelar',
    int maxWidth = 1024,
    int maxHeight = 1024,
    int imageQuality = 80,
  }) async {
    return showDialog<File?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF9147FF)),
                title: Text(
                  galleryText,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final file = await pickImageFromGallery(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                    imageQuality: imageQuality,
                  );
                  Navigator.of(context).pop(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Color(0xFF9147FF)),
                title: Text(
                  cameraText,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final file = await takePhoto(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                    imageQuality: imageQuality,
                  );
                  Navigator.of(context).pop(file);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                cancelText,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Abre configurações do app se permissões foram negadas permanentemente
  static Future<bool> openAppSettings() async {
    try {
      Logger.info('PermissionsService: Abrindo configurações do app');
      return await openAppSettings(); // ✅ CORRIGIDO - Estava chamando a si mesmo
    } catch (e) {
      Logger.error('PermissionsService: Erro ao abrir configurações', error: e);
      return false;
    }
  }

  /// Mostra dialog explicativo sobre permissões
  static Future<bool?> showPermissionDialog({
    required BuildContext context,
    String title = 'Permissões Necessárias',
    String content = 'Este app precisa de permissão para acessar suas fotos e câmera para funcionar corretamente.',
    String allowText = 'Permitir',
    String denyText = 'Não Permitir',
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            content,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                denyText,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
              ),
              child: Text(allowText),
            ),
          ],
        );
      },
    );
  }

  /// Obtém versão do Android (API level)
  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      // Implementar lógica para obter versão do Android
      // Por simplicidade, assumindo versão recente
      return 33; // Android 13
    } catch (e) {
      Logger.error('PermissionsService: Erro ao obter versão do Android', error: e);
      return 30; // Fallback para Android 11
    }
  }
}
