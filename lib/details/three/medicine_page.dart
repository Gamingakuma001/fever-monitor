import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class MedicinePage extends StatelessWidget {
  final String uid;
  const MedicinePage({super.key, required this.uid});

  Future<Map<String, List<Map<String, dynamic>>>> _fetchAllMedicines() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .get();

    Map<String, List<Map<String, dynamic>>> grouped = {
      'breakfast': [],
      'lunch': [],
      'dinner': [],
    };

    for (var doc in querySnapshot.docs) {
      final data = doc.data();

      if (data['medicine'] == null) continue;

      final medName = data['medicine'];

      for (var meal in ['breakfast', 'lunch', 'dinner']) {
        final entry = data[meal];
        if (entry != null &&
            entry['dosage'] != null &&
            entry['dosage'].toString().trim().isNotEmpty) {
          grouped[meal]!.add({
            'name': medName,
            'dosage': entry['dosage'],
            'timing': entry['time'],
          });
        }
      }
    }

    return grouped;
  }

  void _showMealDetails(BuildContext context, String meal, List<Map<String, dynamic>> meds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: meds.isEmpty
            ? const Center(child: Text("No medicine data available."))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${meal[0].toUpperCase()}${meal.substring(1)} Medicines",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: meds.length,
                      itemBuilder: (context, index) {
                        final med = meds[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.medication_outlined, color: Colors.blueAccent),
                            title: Text(
                              med['name'] ?? 'Unnamed',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              "Dosage: ${med['dosage'] ?? '--'}\nWhen: ${med['timing'] ?? '--'}",
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, String meal, List<Map<String, dynamic>> meds, Color color) {
    return GestureDetector(
      onTap: () => _showMealDetails(context, meal, meds),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.medical_services_outlined, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${meal[0].toUpperCase()}${meal.substring(1)} Medicines',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meds.length} medicine(s) scheduled',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medicine Schedule"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        elevation: 3,
      ),
      body: FutureBuilder(
        future: _fetchAllMedicines(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          return ListView(
            children: [
              _buildMealCard(context, 'breakfast', data['breakfast']!, Colors.amber),
              _buildMealCard(context, 'lunch', data['lunch']!, Colors.orange),
              _buildMealCard(context, 'dinner', data['dinner']!, Colors.deepPurple),
            ],
          );
        },
      ),
    );
  }
}
