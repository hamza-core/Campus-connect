import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/storage/complaint_photo_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test('Complaint photos are isolated by account and complaint ID', () async {
    final database = await databaseFactoryMemory.openDatabase('photos-test');
    addTearDown(database.close);
    final writer = ComplaintPhotoStore(openDatabase: () async => database);
    final reader = ComplaintPhotoStore(openDatabase: () async => database);
    await writer.save('ali', 'complaint-a', [
      Uint8List.fromList([1, 2, 3]),
    ]);

    expect(await reader.read('ali', 'complaint-a'), [
      [1, 2, 3],
    ]);
    expect(await reader.read('sara', 'complaint-a'), isEmpty);
    expect(await reader.read('ali', 'complaint-b'), isEmpty);
  });
}
