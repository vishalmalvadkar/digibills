import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:printing/printing.dart'; 
import 'package:media_store_plus/media_store_plus.dart';
import '../theme/app_colors.dart';
import 'snackbar_helper.dart';
import 'notification_helper.dart';
import 'package:open_filex/open_filex.dart';

class FileDownloadHelper {
  static Future<void> downloadFile(
    List<int> bytes, 
    String fileName, 
    String extension, {
    String? text,
    String? mimeType, 
  }) async {
    final String effectiveMimeType = mimeType ?? _getMimeType(extension);

    _showDownloadBanner('Downloading $fileName...', isProgress: true);

    File? savedFile;

    try {
      if (kIsWeb) {
        final blob = html.Blob([bytes], effectiveMimeType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = '$fileName.$extension';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        if (Platform.isAndroid) {
          // Use temporary directory for opening via FileProvider (more reliable)
          final directory = await getTemporaryDirectory();
          savedFile = File('${directory.path}/$fileName.$extension');
          await savedFile.writeAsBytes(bytes, flush: true);

          // Create a SEPARATE file for MediaStore, as it might move/delete the source file
          final tempFileForMediaStore = File('${directory.path}/${fileName}_temp.$extension');
          await tempFileForMediaStore.writeAsBytes(bytes, flush: true);

          // Also save to Public Downloads for user access
          final MediaStore mediaStore = MediaStore();
          await mediaStore.saveFile(
            tempFilePath: tempFileForMediaStore.path,
            dirType: DirType.download,
            dirName: DirName.download,
            relativePath: FilePath.root,
          );
        } else if (Platform.isIOS) {
          final directory = await getTemporaryDirectory();
          savedFile = File('${directory.path}/$fileName.$extension');
          await savedFile.writeAsBytes(bytes);

          if (extension.toLowerCase() == 'pdf') {
            await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: '$fileName.$extension');
          } else {
            await Share.shareXFiles([XFile(savedFile.path, mimeType: effectiveMimeType)], subject: text ?? 'Here is your $fileName report');
          }
        } else {
          String? path;
          if (Platform.isWindows) {
            final downloads = await getDownloadsDirectory();
            path = downloads?.path; 
          }
          path ??= (await getApplicationDocumentsDirectory()).path;
          savedFile = File('$path/$fileName.$extension');
          await savedFile.writeAsBytes(bytes);
        }
      }

      _hideDownloadBanner();

      if (!kIsWeb && savedFile != null) {
         if (Platform.isAndroid) {
            await NotificationHelper.showNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: 'Download Complete',
              body: '$fileName.$extension',
              payload: '${savedFile.path}|$effectiveMimeType',
            );
         }

         _showDownloadBanner(
           'File downloaded successfully!', 
           isProgress: false,
           actionLabel: 'OPEN',
           onAction: () async {
             final result = await OpenFilex.open(savedFile!.path, type: effectiveMimeType);
             if (result.type != ResultType.done) {
               SnackbarHelper.scaffoldMessengerKey.currentState?.showSnackBar(
                 SnackBar(content: Text('Could not open file: ${result.message}'), backgroundColor: AppColors.error)
               );
             }
           },
         );
      } else {
         _showDownloadBanner('File downloaded successfully!', isProgress: false);
      }

      Future.delayed(const Duration(seconds: 5), () => _hideDownloadBanner());

    } catch (e) {
      _hideDownloadBanner();
      SnackbarHelper.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error)
      );
      rethrow;
    }
  }

  static void _showDownloadBanner(
    String message, {
    required bool isProgress, 
    String? actionLabel, 
    VoidCallback? onAction
  }) {
    final messenger = SnackbarHelper.scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.removeCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Row(
          children: [
            if (isProgress) 
              const SizedBox(
                width: 18, 
                height: 18, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
              )
            else 
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)
              )
            ),
          ],
        ),
        backgroundColor: isProgress ? AppColors.primary : AppColors.success,
        actions: [
          if (actionLabel != null && onAction != null)
             TextButton(
              onPressed: () {
                onAction();
                messenger.hideCurrentMaterialBanner();
              },
              child: Text(actionLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          if (!isProgress)
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: const Text('DISMISS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  static void _hideDownloadBanner() {
    SnackbarHelper.scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
  }

  static String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls': return 'application/vnd.ms-excel';
      case 'zip': return 'application/zip';
      case 'csv': return 'text/csv';
      case 'png': return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      default: return 'application/octet-stream';
    }
  }
}
