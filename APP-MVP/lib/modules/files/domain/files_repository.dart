import 'stored_file.dart';
abstract interface class FilesRepository {Future<StoredFile> upload({required List<int> bytes,required String fileName,required String category});Future<String> accessUrl(String fileUrl);}
