import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Tambahan untuk upload file
import 'package:image_picker/image_picker.dart'; // Tambahan untuk pilih gambar
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'dart:async';
import 'dart:io'; // Tambahan untuk File

// ID unik aplikasi untuk database agar tidak tercampur dengan proyek lain
const String appId = "presensi-leilem-shergio";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isFirebaseReady = false;
  String errorMessage = "";

  try {
    await Firebase.initializeApp();
    final auth = FirebaseAuth.instance;
    // Autentikasi anonim untuk akses cepat tanpa pendaftaran manual
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    isFirebaseReady = true;
  } catch (e) {
    isFirebaseReady = false;
    errorMessage = e.toString();
  }
  
  runApp(AppPresensi(isReady: isFirebaseReady, error: errorMessage));
}

class AppPresensi extends StatelessWidget {
  final bool isReady;
  final String error;
  const AppPresensi({super.key, required this.isReady, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presensi Leilem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        useMaterial3: true,
      ),
      home: isReady 
        ? const LoginPage() 
        : Scaffold(
            body: Center(child: Text("Error Konfigurasi Firebase: $error")),
          ),
    );
  }
}

// --- HELPER UNTUK PROFIL PENGGUNA ---
class UserDataHelper {
  static Future<Map<String, dynamic>?> getUser(String id) async {
    var doc = await FirebaseFirestore.instance
        .collection('artifacts').doc(appId)
        .collection('public').doc('data')
        .collection('users').doc(id).get();
    return doc.exists ? doc.data() : null;
  }

  static Future<void> updateUser(String id, String nama, String photo, String role) async {
    await FirebaseFirestore.instance
        .collection('artifacts').doc(appId)
        .collection('public').doc('data')
        .collection('users').doc(id).set({
      'id': id,
      'nama': nama,
      'photo_url': photo,
      'role': role,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Fungsi untuk mengunggah foto ke Firebase Storage
  static Future<String> uploadProfilePhoto(String id, File imageFile) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('artifacts/$appId/users/$id/profile_photo.jpg');
    
    await storageRef.putFile(imageFile);
    return await storageRef.getDownloadURL();
  }
}

// --- HALAMAN LOGIN ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();

  void _login() {
    String id = _idController.text.trim();
    if (id.isEmpty) return;

    if (id.startsWith('19') || id.startsWith('20')) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GuruMainPage(nip: id)));
    } else if (id.startsWith('21')) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SiswaMainPage(nis: id)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID Tidak Valid. Gunakan NIP atau NIS.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(30.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 100, color: Colors.blue),
                const SizedBox(height: 16),
                const Text('Presensi Leilem', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                const Text('SMP Kristen Leilem', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 40),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    labelText: 'Masukkan NIP atau NIS', 
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, 
                      foregroundColor: Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    child: const Text('MASUK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- PORTAL GURU ---
class GuruMainPage extends StatefulWidget {
  final String nip;
  const GuruMainPage({super.key, required this.nip});
  @override
  State<GuruMainPage> createState() => _GuruMainPageState();
}

class _GuruMainPageState extends State<GuruMainPage> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      GuruDashboard(nip: widget.nip), 
      GuruLaporanPage(nip: widget.nip), 
      GuruProfilPage(id: widget.nip, role: "Guru")
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.summarize), label: 'Laporan'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class GuruDashboard extends StatelessWidget {
  final String nip;
  const GuruDashboard({super.key, required this.nip});

  void _addSubject(BuildContext context) async {
    final nameController = TextEditingController();
    final classController = TextEditingController();
    
    var profil = await UserDataHelper.getUser(nip);
    String namaGuru = profil?['nama'] ?? nip;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Mapel Baru'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Mata Pelajaran')),
          TextField(controller: classController, decoration: const InputDecoration(labelText: 'Kelas')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () async {
            if (nameController.text.isEmpty) return;
            await FirebaseFirestore.instance
              .collection('artifacts').doc(appId)
              .collection('public').doc('data')
              .collection('subjects').add({
              'nama_mapel': nameController.text,
              'kelas': classController.text,
              'token': List.generate(6, (i) => Random().nextInt(10)).join(),
              'id_guru': nip,
              'nama_guru': namaGuru,
              'created_at': FieldValue.serverTimestamp(),
            });
            if (context.mounted) Navigator.pop(context);
          }, child: const Text('Simpan')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Guru')),
      floatingActionButton: FloatingActionButton(onPressed: () => _addSubject(context), child: const Icon(Icons.add)),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
          .collection('artifacts').doc(appId)
          .collection('public').doc('data')
          .collection('subjects').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var myDocs = snapshot.data!.docs.where((d) => d.get('id_guru') == nip).toList();
          if (myDocs.isEmpty) return const Center(child: Text('Belum ada mata pelajaran.'));
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myDocs.length,
            itemBuilder: (context, index) {
              final doc = myDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final String namaMapel = data.containsKey('nama_mapel') ? data['nama_mapel'] : "Tanpa Nama";
              final String kelas = data.containsKey('kelas') ? data['kelas'] : "-";
              final String token = data.containsKey('token') ? data['token'] : "-";
              final String namaGuru = data.containsKey('nama_guru') ? data['nama_guru'] : nip;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  title: Text(namaMapel, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Kelas: $kelas | Token: $token'),
                  trailing: IconButton(
                    icon: const Icon(Icons.qr_code_2, color: Colors.blue),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QRGeneratorPage(subjectId: doc.id, subjectName: namaMapel, namaGuru: namaGuru))),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- GENERATOR QR & ABSEN MANUAL (CHECKLIST) ---
class QRGeneratorPage extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String namaGuru;
  const QRGeneratorPage({super.key, required this.subjectId, required this.subjectName, required this.namaGuru});
  @override
  State<QRGeneratorPage> createState() => _QRGeneratorPageState();
}

class _QRGeneratorPageState extends State<QRGeneratorPage> {
  String qrData = "";
  void _generateNewQR() {
    int currentMinute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    setState(() => qrData = "${widget.subjectId}_$currentMinute");
  }

  Future<void> _absenManual(String nis) async {
    String today = DateTime.now().toString().split(' ')[0];
    await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('attendance').add({
      'id_mapel': widget.subjectId,
      'nama_mapel': widget.subjectName,
      'nama_guru': widget.namaGuru,
      'nis': nis,
      'tanggal': today,
      'jam': "${TimeOfDay.now().format(context)} (Manual)",
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void initState() {
    super.initState();
    _generateNewQR();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectName)),
      body: Column(
        children: [
          const SizedBox(height: 15),
          QrImageView(data: qrData, size: 180),
          const SizedBox(height: 10),
          ElevatedButton.icon(onPressed: _generateNewQR, icon: const Icon(Icons.refresh), label: const Text('PERBARUI QR')),
          const Divider(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(alignment: Alignment.centerLeft, child: Text("Status Kehadiran Siswa Terdaftar", style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('enrollments').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> enrollSnapshot) {
                return StreamBuilder(
                  stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('attendance').snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> attendanceSnapshot) {
                    if (!enrollSnapshot.hasData || !attendanceSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var enrolled = enrollSnapshot.data!.docs.where((doc) => doc.get('id_mapel') == widget.subjectId).toList();
                    String today = DateTime.now().toString().split(' ')[0];
                    var attendedNisList = attendanceSnapshot.data!.docs
                        .where((doc) => doc.get('id_mapel') == widget.subjectId && doc.get('tanggal') == today)
                        .map((doc) => doc.get('nis')).toList();

                    if (enrolled.isEmpty) return const Center(child: Text("Belum ada siswa yang bergabung."));

                    return ListView.builder(
                      itemCount: enrolled.length,
                      itemBuilder: (context, index) {
                        String nis = enrolled[index].get('nis');
                        bool hasAttended = attendedNisList.contains(nis);
                        return ListTile(
                          leading: Icon(hasAttended ? Icons.check_circle : Icons.error_outline, color: hasAttended ? Colors.green : Colors.grey),
                          title: Text("NIS: $nis"),
                          subtitle: Text(hasAttended ? "Hadir" : "Belum Absen"),
                          trailing: !hasAttended ? ElevatedButton(
                            onPressed: () => _absenManual(nis),
                            child: const Text("Absen Manual"),
                          ) : const Icon(Icons.verified, color: Colors.green),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- PORTAL SISWA ---
class SiswaMainPage extends StatefulWidget {
  final String nis;
  const SiswaMainPage({super.key, required this.nis});
  @override
  State<SiswaMainPage> createState() => _SiswaMainPageState();
}

class _SiswaMainPageState extends State<SiswaMainPage> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      SiswaDashboard(nis: widget.nis), 
      SiswaRiwayatPage(nis: widget.nis), 
      SiswaProfilPage(id: widget.nis, role: "Siswa")
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: Colors.green,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class SiswaDashboard extends StatelessWidget {
  final String nis;
  const SiswaDashboard({super.key, required this.nis});

  void _joinSubjectDialog(BuildContext context) {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gabung Kelas'),
        content: TextField(controller: tokenController, decoration: const InputDecoration(labelText: 'Masukkan Token 6 Digit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              String token = tokenController.text.trim();
              var res = await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('subjects').where('token', isEqualTo: token).get();
              if (res.docs.isNotEmpty) {
                var mapelDoc = res.docs.first;
                final mapelData = mapelDoc.data();
                await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('enrollments').add({
                  'id_mapel': mapelDoc.id, 
                  'nama_mapel': mapelData.containsKey('nama_mapel') ? mapelData['nama_mapel'] : "Tanpa Nama", 
                  'kelas': mapelData.containsKey('kelas') ? mapelData['kelas'] : "-", 
                  'nis': nis, 
                  'enrolled_at': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil mendaftar ke kelas!')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token tidak ditemukan!')));
              }
            },
            child: const Text('Gabung'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Siswa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(onPressed: () => _joinSubjectDialog(context), icon: const Icon(Icons.add), label: const Text('Mendaftar Mapel Baru'), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Align(alignment: Alignment.centerLeft, child: Text('Kelas Terdaftar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('enrollments').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var myEnrollments = snapshot.data!.docs.where((doc) => doc.get('nis') == nis).toList();
                if (myEnrollments.isEmpty) return const Center(child: Text('Belum ada kelas.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myEnrollments.length,
                  itemBuilder: (context, index) {
                    final data = myEnrollments[index].data() as Map<String, dynamic>;
                    final String namaMapel = data.containsKey('nama_mapel') ? data['nama_mapel'] : "Tanpa Nama";
                    final String kelas = data.containsKey('kelas') ? data['kelas'] : "-";
                    return Card(child: ListTile(leading: const Icon(Icons.book), title: Text(namaMapel, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Kelas: $kelas')));
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QRScannerPage(nis: nis))), icon: const Icon(Icons.qr_code_scanner), label: const Text('SCAN SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
          )
        ],
      ),
    );
  }
}

class SiswaRiwayatPage extends StatelessWidget {
  final String nis;
  const SiswaRiwayatPage({super.key, required this.nis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Absensi')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('attendance').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var myAttendance = snapshot.data!.docs.where((d) => d.get('nis') == nis).toList();
          if (myAttendance.isEmpty) return const Center(child: Text("Anda belum memiliki catatan kehadiran."));
          
          return ListView.builder(
            itemCount: myAttendance.length,
            itemBuilder: (context, index) {
              var doc = myAttendance[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green), 
                  title: Text(data.containsKey('nama_mapel') ? data['nama_mapel'] : "Mata Pelajaran (${data['id_mapel']})", 
                      style: const TextStyle(fontWeight: FontWeight.bold)), 
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Pengajar: ${data.containsKey('nama_guru') ? data['nama_guru'] : '-'}"),
                      Text("Waktu: ${data.containsKey('tanggal') ? data['tanggal'] : '-'} | ${data.containsKey('jam') ? data['jam'] : '-'}"),
                    ],
                  )
                )
              );
            },
          );
        },
      ),
    );
  }
}

// --- INTEGRASI PROFIL & EDIT DATA DENGAN UPLOAD FOTO ---
class ProfileScreen extends StatefulWidget {
  final String id;
  final String role;
  final Color color;
  const ProfileScreen({super.key, required this.id, required this.role, required this.color});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _namaController = TextEditingController();
  bool _isUploading = false;

  // Fungsi untuk memilih dan mengunggah gambar
  Future<void> _pickAndUploadImage(String currentNama) async {
    final ImagePicker picker = ImagePicker();
    // Memilih sumber gambar (Galeri)
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        File file = File(image.path);
        // Unggah ke Storage dan dapatkan URL-nya
        String downloadUrl = await UserDataHelper.uploadProfilePhoto(widget.id, file);
        // Simpan URL ke Firestore
        await UserDataHelper.updateUser(widget.id, currentNama, downloadUrl, widget.role);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto profil berhasil diperbarui!")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengunggah: $e")));
        }
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _editNama(String currentNama, String currentPhoto) {
    _namaController.text = currentNama;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ubah Nama"),
        content: TextField(controller: _namaController, decoration: const InputDecoration(labelText: "Nama Lengkap")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(onPressed: () async {
            await UserDataHelper.updateUser(widget.id, _namaController.text, currentPhoto, widget.role);
            if (context.mounted) Navigator.pop(context);
          }, child: const Text("Simpan")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Akun')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('users').doc(widget.id).snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          String nama = widget.id;
          String photo = "";
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            nama = userData.containsKey('nama') ? userData['nama'] : widget.id;
            photo = userData.containsKey('photo_url') ? userData['photo_url'] : "";
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 70, 
                      backgroundColor: widget.color.withOpacity(0.2), 
                      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty ? Icon(Icons.person, size: 70, color: widget.color) : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 20,
                      child: IconButton(
                        onPressed: () => _pickAndUploadImage(nama),
                        icon: const Icon(Icons.camera_alt, size: 20, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(nama, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => _editNama(nama, photo), icon: const Icon(Icons.edit, size: 18)),
                  ],
                ),
                Text("${widget.role} | ID: ${widget.id}", style: const TextStyle(color: Colors.grey)),
                const Divider(height: 40),
                ListTile(leading: const Icon(Icons.school), title: const Text('SMP Kristen Leilem')),
                ListTile(leading: const Icon(Icons.verified), title: const Text('Status: Terverifikasi')),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginPage())),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('KELUAR (LOGOUT)', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}

class GuruProfilPage extends StatelessWidget {
  final String id;
  final String role;
  const GuruProfilPage({super.key, required this.id, required this.role});
  @override
  Widget build(BuildContext context) { return ProfileScreen(id: id, role: role, color: Colors.blue); }
}

class SiswaProfilPage extends StatelessWidget {
  final String id;
  final String role;
  const SiswaProfilPage({super.key, required this.id, required this.role});
  @override
  Widget build(BuildContext context) { return ProfileScreen(id: id, role: role, color: Colors.green); }
}

// --- MODUL SCANNER & LOGIKA VALIDASI QR ---
class QRScannerPage extends StatefulWidget {
  final String nis;
  const QRScannerPage({super.key, required this.nis});
  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool isScanning = true;

  Future<void> _processQR(String rawData) async {
    if (!isScanning) return;
    setState(() => isScanning = false);

    try {
      List<String> parts = rawData.split('_');
      if (parts.length != 2) throw "QR Code Tidak Valid";
      String subjectId = parts[0];
      int qrMinute = int.parse(parts[1]);
      int currentMinute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      String today = DateTime.now().toString().split(' ')[0];

      if ((currentMinute - qrMinute).abs() > 1) throw "QR Code sudah kadaluwarsa.";

      var mapelDoc = await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('subjects').doc(subjectId).get();
      if (!mapelDoc.exists) throw "Informasi mata pelajaran tidak ditemukan.";

      var enrollments = await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('enrollments').get();
      bool isEnrolled = enrollments.docs.any((doc) => doc.get('nis') == widget.nis && doc.get('id_mapel') == subjectId);
      if (!isEnrolled) throw "Anda belum terdaftar di mata pelajaran ini.";

      var attendanceCheck = await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('attendance').get();
      bool alreadyAttended = attendanceCheck.docs.any((doc) => doc.get('id_mapel') == subjectId && doc.get('nis') == widget.nis && doc.get('tanggal') == today);
      if (alreadyAttended) throw "Anda sudah melakukan presensi hari ini.";

      final mapelData = mapelDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('attendance').add({
        'id_mapel': subjectId,
        'nama_mapel': mapelData.containsKey('nama_mapel') ? mapelData['nama_mapel'] : "Tanpa Nama",
        'nama_guru': mapelData.containsKey('nama_guru') ? mapelData['nama_guru'] : "-",
        'nis': widget.nis,
        'tanggal': today,
        'jam': TimeOfDay.now().format(context),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Sukses!'), content: const Text('Kehadiran Anda berhasil dicatat.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Selesai'))])).then((_) => Navigator.pop(context));
      }
    } catch (e) {
      if (mounted) {
        showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Gagal Presensi'), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))])).then((_) => setState(() => isScanning = true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner QR Guru')),
      body: MobileScanner(onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
          _processQR(barcodes.first.rawValue!);
        }
      }),
    );
  }
}

class GuruLaporanPage extends StatelessWidget {
  final String nip;
  const GuruLaporanPage({super.key, required this.nip});

  Future<void> _generatePdf(BuildContext context, String subjectName, String subjectId) async {
    final pdf = pw.Document();
    var attendanceQuery = await FirebaseFirestore.instance
        .collection('artifacts').doc(appId)
        .collection('public').doc('data')
        .collection('attendance')
        .where('id_mapel', isEqualTo: subjectId)
        .get();

    final List<List<String>> tableData = [['No', 'NIS Siswa', 'Tanggal', 'Waktu']];
    for (var i = 0; i < attendanceQuery.docs.length; i++) {
      var doc = attendanceQuery.docs[i];
      final data = doc.data() as Map<String, dynamic>;
      tableData.add([
        (i + 1).toString(), 
        data.containsKey('nis') ? data['nis'] : '-', 
        data.containsKey('tanggal') ? data['tanggal'] : '-', 
        data.containsKey('jam') ? data['jam'] : '-'
      ]);
    }

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, text: "LAPORAN KEHADIRAN SISWA"),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text("Sekolah: SMP Kristen Leilem"),
              pw.Text("Mata Pelajaran: $subjectName"),
              pw.Text("NIP Pengajar: $nip"),
              pw.Text("Total Kehadiran: ${attendanceQuery.docs.length}"),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), data: tableData),
            ],
          );
        }));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Laporan')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('subjects').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var myDocs = snapshot.data!.docs.where((d) => d.get('id_guru') == nip).toList();
          if (myDocs.isEmpty) return const Center(child: Text("Belum ada data untuk dilaporkan."));
          return ListView.builder(
            itemCount: myDocs.length,
            itemBuilder: (context, index) {
              final doc = myDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String namaMapel = data.containsKey('nama_mapel') ? data['nama_mapel'] : "Tanpa Nama";
              final String kelas = data.containsKey('kelas') ? data['kelas'] : "-";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(namaMapel),
                  subtitle: Text("Kelas: $kelas"),
                  trailing: const Icon(Icons.download),
                  onTap: () => _generatePdf(context, namaMapel, doc.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}