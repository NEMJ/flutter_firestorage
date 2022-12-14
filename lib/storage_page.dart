import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_native_image/flutter_native_image.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({ Key? key }) : super(key: key);

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  final FirebaseStorage storage = FirebaseStorage.instance;
  bool uploading = false;
  double total = 0;
  List<Reference> refs = [];
  List<String> arquivos = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadImages();
  }

  loadImages() async {
    refs = (await storage.ref('images').listAll()).items;
    for(var ref in refs) {
      arquivos.add(await ref.getDownloadURL());
    }
    setState(() {
      loading = false;
    });
  }

  Future<File> compressImage(String filePath) async {
    File compressedFile = await FlutterNativeImage.compressImage(filePath, quality: 70, percentage: 40);
    return compressedFile;
  }

  Future<File?> getImageCompress() async {
    final ImagePicker _picker = ImagePicker();
    XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    File compress = await compressImage(image!.path);
    return compress;
  }

  Future<UploadTask> upload(String path) async {
    File file = File(path);
    try {
      String ref = 'images/img-${DateTime.now().toIso8601String()}.jpg';
      return storage.ref(ref).putFile(file);
    } on FirebaseException catch(e) {
      throw Exception('Erro no upload: ${e.code}');
    }
  }

  pickAndUploadImage() async {
    File? file = await getImageCompress();

    if(file != null) {
      UploadTask task = await upload(file.path);

      task.snapshotEvents.listen((TaskSnapshot snapshot) async {
        if(snapshot.state == TaskState.running) {
          setState(() {
            uploading = true;
            total = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          });
        } else if(snapshot.state == TaskState.success) {
          arquivos.add(await snapshot.ref.getDownloadURL());
          refs.add(snapshot.ref);
          setState(() => uploading = false);
        }
      });
    }
  }

  deleteImage(int index) async {
    await storage.ref(refs[index].fullPath).delete();
    arquivos.removeAt(index);
    refs.removeAt(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: uploading
        ? Text('${total.round()}% enviado')
        : const Text('Firebase Storage'),
        actions: [
          uploading
          ? const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            )
          )
          : IconButton(
            icon: const Icon(Icons.upload),
            onPressed: pickAndUploadImage,
          ),
        ],
        elevation: 0,
      ),
      body: loading
      ? const Center(child: CircularProgressIndicator(),)
      : Padding(
        padding: const EdgeInsets.all(24),
        child: arquivos.isEmpty
        ? const Center(child: Text('N??o h?? imagens ainda'))
        : ListView.builder(itemBuilder: (_, index) {
          return ListTile(
            leading: SizedBox(
              width: 60,
              height: 40,
              child: Image.network(
                arquivos[index],
                fit: BoxFit.cover
              ),
            ),
            title: Text(refs[index].fullPath),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => deleteImage(index),
            ),
          );
        },
        itemCount: arquivos.length),
      ),
    );
  }
}