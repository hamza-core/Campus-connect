import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast/sembast.dart';

import '../errors/app_exception.dart';
import 'complaint_photo_database.dart';

final class ComplaintPhotoStore {
  ComplaintPhotoStore({Future<Database> Function()? openDatabase})
    : _openDatabase = openDatabase ?? openComplaintPhotoDatabase;

  static final instance = ComplaintPhotoStore();
  static final _store = StoreRef<String, List<Object?>>('complaint_photos');
  final Future<Database> Function() _openDatabase;
  Future<Database>? _database;

  Future<Database> _open() async {
    try {
      return await (_database ??= _openDatabase());
    } on Exception {
      _database = null;
      rethrow;
    }
  }

  String _key(String ownerId, String complaintId) =>
      jsonEncode([ownerId, complaintId]);

  Future<void> save(
    String ownerId,
    String complaintId,
    List<Uint8List> photos,
  ) async {
    try {
      await _store
          .record(_key(ownerId, complaintId))
          .put(await _open(), photos.map(base64Encode).toList());
    } on Exception {
      throw const ServerException(
        'Complaint submitted. Photos could not be saved on this device.',
      );
    }
  }

  Future<List<Uint8List>> read(String ownerId, String complaintId) async {
    try {
      final photos = await _store
          .record(_key(ownerId, complaintId))
          .get(await _open());
      return photos?.cast<String>().map(base64Decode).toList() ?? const [];
    } on Exception {
      throw const ServerException('Photos could not be opened on this device.');
    }
  }
}
