import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import './details/user_detail_page.dart';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  final List<Map<String, dynamic>> _users = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 5;
  String _searchQuery = '';
  bool _onlyHighFevers = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent &&
          !_isLoading &&
          _hasMore) {
        _fetchUsers();
      }
    });
  }

  DateTime parseFirestoreTimestamp(dynamic tsField) {
    if (tsField is Timestamp) {
      return tsField.toDate();
    } else if (tsField is String) {
      return DateTime.tryParse(tsField) ?? DateTime(2000);
    } else {
      return DateTime(2000);
    }
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _users.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    await _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    Query query = FirebaseFirestore.instance
        .collection('users')
        .orderBy(FieldPath.documentId)
        .limit(_pageSize);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }

    // Snippet updated here
    for (var doc in snapshot.docs) {
      final dataMap = doc.data() as Map<String, dynamic>? ?? {};
      final profile = dataMap['profile'] as Map<String, dynamic>? ?? {};
      final uid = doc.id;

      // Count high temperatures
      final tempSnap = await doc.reference.collection('temperatureEntries').get();
      int highCount = 0;
      for (var t in tempSnap.docs) {
        double? temp = double.tryParse(t['temperature'].toString());
        if (temp != null && temp >= 100.4) highCount++;
      }

      if (_onlyHighFevers && highCount == 0) continue;

      final name = profile['name']?.toString().toLowerCase() ?? '';
      if (_searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase())) {
        _users.add({
          'uid': uid,
          'profile': profile,
          'highTempCount': highCount,
        });
      }
    }

    _users.sort((a, b) => b['highTempCount'].compareTo(a['highTempCount']));

    setState(() {
      _lastDoc = snapshot.docs.last;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _users.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    _fetchUsers();
  }

  Future<void> _exportAllUsersToCSV() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    List<List<String>> csvData = [
      [
        'UID',
        'Name',
        'Age',
        'Sex',
        'Parent',
        'Contact',
        'DataType',
        'Timestamp',
        'Temperature',
        'Medicine',
        'Dosage',
        'When'
      ]
    ];

    for (var userDoc in usersSnapshot.docs) {
      // Snippet updated here
      final dataMap = userDoc.data() as Map<String, dynamic>? ?? {};
      final profile = dataMap['profile'] as Map<String, dynamic>? ?? {};
      final uid = userDoc.id;

      String name = profile['name'] ?? '';
      String age = profile['age']?.toString() ?? '';
      String sex = profile['sex'] ?? '';
      String parent = profile['parentName'] ?? '';
      String contact = profile['contact'] ?? '';

      // Temperature Entries
      final tempSnap =
          await userDoc.reference.collection('temperatureEntries').get();
      for (var t in tempSnap.docs) {
        final temp = t['temperature']?.toString() ?? '';
        final tsRaw = t['timestamp'];
        final ts =
            tsRaw is Timestamp ? tsRaw.toDate() : DateTime.tryParse(tsRaw.toString());
        csvData.add([
          uid,
          name,
          age,
          sex,
          parent,
          contact,
          'Temperature',
          ts != null ? ts.toIso8601String() : '',
          temp,
          '',
          '',
          ''
        ]);
      }

      // Medicines
      final medSnap = await userDoc.reference.collection('medicines').get();
      for (var m in medSnap.docs) {
        final data = m.data();
        final medName = data['medicine'] ?? '';

        for (var meal in ['breakfast', 'lunch', 'dinner']) {
          final entry = data[meal];
          if (entry != null && entry['dosage'] != null) {
            csvData.add([
              uid,
              name,
              age,
              sex,
              parent,
              contact,
              'Medicine',
              '',
              '',
              medName,
              entry['dosage'].toString(),
              meal,
            ]);
          }
        }
      }
    }

    final csv = const ListToCsvConverter().convert(csvData);

    final dir = await getExternalStorageDirectory();
    final file = File('${dir!.path}/all_users_data.csv');
    await file.writeAsString(csv);

    Share.shareXFiles([XFile(file.path)], text: 'All User Data CSV');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        elevation: 4,
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
        title: Text(
          'All Users',
          style: GoogleFonts.poppins(
            color: Colors.blueAccent,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportAllUsersToCSV,
            tooltip: 'Export All to CSV',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile(
              value: _onlyHighFevers,
              onChanged: (val) {
                setState(() {
                  _onlyHighFevers = val;
                  _users.clear();
                  _lastDoc = null;
                  _hasMore = true;
                });
                _fetchUsers();
              },
              title: const Text("Show only high-fever users (≥ 100.4°F)"),
              activeColor: Colors.redAccent,
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshUsers,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _users.length + (_isLoading ? 1 : 0),
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  if (index == _users.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final user = _users[index];
                  final profile = user['profile'];
                  final uid = user['uid'];
                  final highCount = user['highTempCount'];

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: highCount > 0 ? Colors.red[50] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: profile['profileImageUrl'] != null
                            ? NetworkImage(profile['profileImageUrl'])
                            : null,
                        child: profile['profileImageUrl'] == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile['name'] ?? 'No Name',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (highCount > 0)
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.red),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Age: ${profile['age'] ?? '--'}"),
                            Text("Sex: ${profile['sex'] ?? '--'}"),
                            Text("Parent: ${profile['parentName'] ?? '--'}"),
                            Text("Contact: ${profile['contact'] ?? '--'}"),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UserDetailPage(uid: uid, profile: profile),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}