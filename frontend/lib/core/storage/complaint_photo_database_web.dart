import 'package:sembast_web/sembast_web.dart';

Future<Database> openComplaintPhotoDatabase() =>
    databaseFactoryWeb.openDatabase('campusconnect_complaint_photos');
