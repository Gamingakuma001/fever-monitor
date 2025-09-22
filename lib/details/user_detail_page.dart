import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import './three/medicine_page.dart';
import './three/temperature_page.dart';
import './three/graph_page.dart';

class UserDetailPage extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> profile;

  const UserDetailPage({super.key, required this.uid, required this.profile});

  Future<void> _exportUserDataToCSV(BuildContext context) async {
    try {
      final temperatureSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('temperatureEntries')
          .orderBy('timestamp')
          .get();

      final medicineSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('medicines')
          .get();

      List<List<dynamic>> rows = [];

      rows.add(["User Details"]);
      rows.add(["Name", profile['name'] ?? '']);
      rows.add(["Age", profile['age'] ?? '']);
      rows.add(["Sex", profile['sex'] ?? '']);
      rows.add(["Parent", profile['parentName'] ?? '']);
      rows.add(["Contact", profile['contact'] ?? '']);
      rows.add([]);

      rows.add(["Temperature Records"]);
      rows.add(["Timestamp", "Temperature (°F)"]);
      for (var doc in temperatureSnapshot.docs) {
        final data = doc.data();
        final ts = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now();
        rows.add([ts.toString(), data['temperature'].toString()]);
      }

      rows.add([]);
      rows.add(["Medicine Schedule"]);
      rows.add(["Medicine", "Dosage", "Time", "Meal"]);
      for (var doc in medicineSnapshot.docs) {
        final data = doc.data();
        final medicine = data['medicine'] ?? '';

        for (final meal in ['breakfast', 'lunch', 'dinner']) {
          final entry = data[meal];
          if (entry != null && entry['dosage'] != null) {
            rows.add([
              medicine,
              entry['dosage'],
              entry['time'] ?? '',
              meal,
            ]);
          }
        }
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/${profile['name'] ?? 'user'}_data.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: "Here is the CSV export for ${profile['name'] ?? 'User'}");

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${profile['name'] ?? 'User'}'s Details",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportUserDataToCSV(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Text("Export CSV"),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 30),
            _buildNavigationCard(
              context,
              "🩺  Medicines",
              MedicinePage(uid: uid),
              Colors.blue[100]!,
            ),
            _buildNavigationCard(
              context,
              "🌡️  Temperature",
              TemperaturePage(uid: uid),
              Colors.orange[100]!,
            ),
            _buildNavigationCard(
              context,
              "📈  Visual Graph",
              GraphPage(uid: uid),
              Colors.green[100]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: profile['profileImageUrl'] != null && profile['profileImageUrl'] != ''
                ? NetworkImage(profile['profileImageUrl'])
                : const AssetImage('assets/default_profile.png') as ImageProvider,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['name'] ?? 'Unknown',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text("Age: ${profile['age'] ?? '--'}", style: const TextStyle(color: Colors.white)),
                Text("Sex: ${profile['sex'] ?? '--'}", style: const TextStyle(color: Colors.white)),
                Text("Parent: ${profile['parentName'] ?? '--'}", style: const TextStyle(color: Colors.white)),
                Text("Contact: ${profile['contact'] ?? '--'}", style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard(
      BuildContext context, String title, Widget page, Color bgColor) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
