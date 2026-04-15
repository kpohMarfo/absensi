import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'dart:async';

// ID unik aplikasi untuk database
const String appId = "presensi-leilem-shergio";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isFirebaseReady = false;
  String errorMessage = "";

  try {
    await Firebase.initializeApp();
    
    final auth = FirebaseAuth.instance;
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
            body: Center(
              child: Text("Error Konfigurasi Firebase: $error"),
            ),
          ),
    );
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

// --- GURU SIDE ---
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
      GuruProfilPage(nip: widget.nip)
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

  void _addSubject(BuildContext context) {
    final nameController = TextEditingController();
    final classController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Mapel'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Mapel')),
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
          
          if (myDocs.isEmpty) return const Center(child: Text('Belum ada mapel.'));
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myDocs.length,
            itemBuilder: (context, index) {
              var doc = myDocs[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  title: Text(doc['nama_mapel'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Kelas: ${doc['kelas']} | Token: ${doc['token']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.qr_code_2, color: Colors.blue),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QRGeneratorPage(subjectId: doc.id, subjectName: doc['nama_mapel']))),
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

    final List<List<String>> tableData = [['No', 'NIS Siswa', 'Tanggal', 'Jam Scan']];
    for (var i = 0; i < attendanceQuery.docs.length; i++) {
      var doc = attendanceQuery.docs[i];
      tableData.add([(i + 1).toString(), doc['nis'], doc['tanggal'], doc['jam']]);
    }

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, text: "Laporan Kehadiran SMP Kristen Leilem"),
              pw.SizedBox(height: 10),
              pw.Text("Mata Pelajaran: $subjectName"),
              pw.Text("NIP Guru: $nip"),
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
      appBar: AppBar(title: const Text('Rekap Laporan')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('subjects').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var myDocs = snapshot.data!.docs.where((d) => d.get('id_guru') == nip).toList();
          if (myDocs.isEmpty) return const Center(child: Text("Belum ada mapel untuk dilaporkan."));
          return ListView.builder(
            itemCount: myDocs.length,
            itemBuilder: (context, index) {
              var doc = myDocs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(doc['nama_mapel']),
                  subtitle: Text("Kelas: ${doc['kelas']}"),
                  trailing: const Icon(Icons.download_rounded),
                  onTap: () => _generatePdf(context, doc['nama_mapel'], doc.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GuruProfilPage extends StatelessWidget {
  final String nip;
  const GuruProfilPage({super.key, required this.nip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Pengajar')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, backgroundColor: Colors.blue, child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 20),
            Text(nip, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Guru Mata Pelajaran', style: TextStyle(color: Colors.grey)),
            const Divider(height: 40),
            ListTile(leading: const Icon(Icons.school), title: const Text('SMP Kristen Leilem')),
            ListTile(leading: const Icon(Icons.verified_user), title: const Text('Status: Aktif')),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginPage())),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('LOGOUT', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- QR GENERATOR PAGE ---
class QRGeneratorPage extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  const QRGeneratorPage({super.key, required this.subjectId, required this.subjectName});
  @override
  State<QRGeneratorPage> createState() => _QRGeneratorPageState();
}

class _QRGeneratorPageState extends State<QRGeneratorPage> {
  String qrData = "";
  void _generateNewQR() {
    int currentMinute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    setState(() => qrData = "${widget.subjectId}_$currentMinute");
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
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                const Text('Scan untuk Presensi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                QrImageView(data: qrData, size: 200),
                const SizedBox(height: 15),
                ElevatedButton.icon(onPressed: _generateNewQR, icon: const Icon(Icons.refresh), label: const Text('PERBARUI KODE QR')),
              ],
            ),
          ),
          const Divider(height: 20),
          const Text("Monitoring Kehadiran Real-time", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('enrollments').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> enrollSnapshot) {
                return StreamBuilder(
                  stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('attendance').snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> attendanceSnapshot) {
                    if (!enrollSnapshot.hasData || !attendanceSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var enrolledStudents = enrollSnapshot.data!.docs.where((doc) => doc.get('id_mapel') == widget.subjectId).toList();
                    String today = DateTime.now().toString().split(' ')[0];
                    var attendedNisList = attendanceSnapshot.data!.docs
                        .where((doc) => doc.get('id_mapel') == widget.subjectId && doc.get('tanggal') == today)
                        .map((doc) => doc.get('nis')).toList();
                    if (enrolledStudents.isEmpty) return const Center(child: Text("Belum ada siswa terdaftar."));
                    return ListView.builder(
                      itemCount: enrolledStudents.length,
                      itemBuilder: (context, index) {
                        var student = enrolledStudents[index];
                        String nis = student.get('nis');
                        bool hasAttended = attendedNisList.contains(nis);
                        return ListTile(
                          leading: Icon(hasAttended ? Icons.check_circle : Icons.error_outline, color: hasAttended ? Colors.green : Colors.red),
                          title: Text("NIS: $nis"),
                          trailing: Text(hasAttended ? "HADIR" : "BELUM SCAN", style: TextStyle(color: hasAttended ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
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

// --- SISWA SIDE ---
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
      SiswaProfilPage(nis: widget.nis)
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: Colors.green,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
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
        title: const Text('Gabung Mata Pelajaran'),
        content: TextField(controller: tokenController, decoration: const InputDecoration(labelText: 'Masukkan Token Guru')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              String token = tokenController.text.trim();
              if (token.isEmpty) return;
              var res = await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('subjects').where('token', isEqualTo: token).get();
              if (res.docs.isNotEmpty) {
                var mapelDoc = res.docs.first;
                await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('enrollments').add({
                  'id_mapel': mapelDoc.id, 'nama_mapel': mapelDoc['nama_mapel'], 'kelas': mapelDoc['kelas'], 'nis': nis, 'enrolled_at': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil bergabung!')));
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
            child: ElevatedButton.icon(onPressed: () => _joinSubjectDialog(context), icon: const Icon(Icons.add), label: const Text('Gabung Mapel Baru'), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Align(alignment: Alignment.centerLeft, child: Text('Daftar Mapel Kamu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('enrollments').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var myEnrollments = snapshot.data!.docs.where((doc) => doc.get('nis') == nis).toList();
                if (myEnrollments.isEmpty) return const Center(child: Text('Belum ada mapel.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myEnrollments.length,
                  itemBuilder: (context, index) {
                    var data = myEnrollments[index];
                    return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.book)), title: Text(data['nama_mapel'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Kelas: ${data['kelas']}')));
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
          if (myAttendance.isEmpty) return const Center(child: Text("Kamu belum pernah melakukan absen."));
          return ListView.builder(
            itemCount: myAttendance.length,
            itemBuilder: (context, index) {
              var data = myAttendance[index];
              return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text("Mapel ID: ${data['id_mapel']}"), subtitle: Text("Tanggal: ${data['tanggal']} | Jam: ${data['jam']}")));
            },
          );
        },
      ),
    );
  }
}

class SiswaProfilPage extends StatelessWidget {
  final String nis;
  const SiswaProfilPage({super.key, required this.nis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Siswa')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, backgroundColor: Colors.green, child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 20),
            Text(nis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Siswa Pelajar', style: TextStyle(color: Colors.grey)),
            const Divider(height: 40),
            ListTile(leading: const Icon(Icons.school), title: const Text('SMP Kristen Leilem')),
            ListTile(leading: const Icon(Icons.check_box), title: const Text('Status Kehadiran: Aktif')),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginPage())),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('LOGOUT', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      if (parts.length != 2) throw "QR Tidak Valid";
      String subjectId = parts[0];
      int qrMinute = int.parse(parts[1]);
      int currentMinute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      String today = DateTime.now().toString().split(' ')[0];

      if ((currentMinute - qrMinute).abs() > 1) throw "QR sudah kadaluwarsa. Silakan minta Guru perbarui QR.";

      var enrollments = await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('enrollments').get();
      bool isEnrolled = enrollments.docs.any((doc) => doc.get('nis') == widget.nis && doc.get('id_mapel') == subjectId);
      if (!isEnrolled) throw "Anda tidak terdaftar di mata pelajaran ini.";

      var attendanceCheck = await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('attendance').get();
      bool alreadyAttended = attendanceCheck.docs.any((doc) => doc.get('id_mapel') == subjectId && doc.get('nis') == widget.nis && doc.get('tanggal') == today);
      if (alreadyAttended) throw "Anda sudah melakukan presensi hari ini.";

      await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('attendance').add({
        'id_mapel': subjectId, 'nis': widget.nis, 'tanggal': today, 'jam': TimeOfDay.now().format(context), 'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Berhasil!'), content: const Text('Kehadiran Anda telah tercatat.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))])).then((_) => Navigator.pop(context));
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
      appBar: AppBar(title: const Text('Scan QR Guru')),
      body: MobileScanner(onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
          _processQR(barcodes.first.rawValue!);
        }
      }),
    );
  }
}