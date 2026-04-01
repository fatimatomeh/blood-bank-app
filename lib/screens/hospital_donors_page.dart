import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';

class HospitalDonorsPage extends StatefulWidget {
  const HospitalDonorsPage({super.key});

  @override
  State<HospitalDonorsPage> createState() => _HospitalDonorsPageState();
}

class _HospitalDonorsPageState extends State<HospitalDonorsPage> {
  List<Map<String, dynamic>> donors = [];
  List<Map<String, dynamic>> filtered = [];
  String hospitalCityAr = "";
  bool isLoading = true;
  String searchQuery = "";
  String? selectedBloodFilter;

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  Future<void> _loadDonors() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // جلب مدينة المستشفى وتحويلها عربي (قد تكون Nablus إنجليزي)
    final hospSnap =
        await FirebaseDatabase.instance.ref("Hospitals/${user.uid}").get();
    if (hospSnap.exists && hospSnap.value is Map) {
      final hospData = Map<String, dynamic>.from(hospSnap.value as Map);
      hospitalCityAr = CityHelper.normalize(hospData['city']?.toString());
    }

    // جلب المتبرعين ومقارنة مدينتهم (عربي) مع مدينة المستشفى (عربي موحد)
    final donorsSnap = await FirebaseDatabase.instance.ref("Donors").get();
    List<Map<String, dynamic>> temp = [];

    if (donorsSnap.exists && donorsSnap.value is Map) {
      final data = Map<String, dynamic>.from(donorsSnap.value as Map);
      data.forEach((key, value) {
        final donor = Map<String, dynamic>.from(value);
        final donorCityAr = CityHelper.normalize(donor['city']?.toString());
        if (donorCityAr == hospitalCityAr) {
          donor['_key'] = key;
          temp.add(donor);
        }
      });
    }

    setState(() {
      donors = temp;
      filtered = temp;
      isLoading = false;
    });
  }

  void _applyFilter() {
    setState(() {
      filtered = donors.where((d) {
        final name = d['fullName']?.toString().toLowerCase() ?? "";
        final blood = d['bloodType']?.toString() ?? "";
        final matchSearch =
            searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());
        final matchBlood =
            selectedBloodFilter == null || blood == selectedBloodFilter;
        return matchSearch && matchBlood;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: Text(
          "المتبرعون${hospitalCityAr.isNotEmpty ? ' - $hospitalCityAr' : ''}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (v) {
                          searchQuery = v;
                          _applyFilter();
                        },
                        decoration: InputDecoration(
                          hintText: "ابحث باسم المتبرع...",
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.red),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip("الكل", null),
                            ...[
                              "A+",
                              "A-",
                              "B+",
                              "B-",
                              "O+",
                              "O-",
                              "AB+",
                              "AB-"
                            ].map((b) => _filterChip(b, b)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "${filtered.length} متبرع",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 70, color: Colors.grey[400]),
                              const SizedBox(height: 15),
                              const Text("لا يوجد متبرعون مطابقون",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black54)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final donor = filtered[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 55,
                                      height: 55,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          donor['bloodType'] ?? "?",
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            donor['fullName'] ?? "غير محدد",
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "📍 ${donor['city'] ?? 'غير محدد'}",
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13),
                                          ),
                                          Text(
                                            "🩸 عدد التبرعات: ${donor['donationCount'] ?? '0'}",
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                          if (donor['lastDonation'] != null &&
                                              donor['lastDonation']
                                                  .toString()
                                                  .isNotEmpty)
                                            Text(
                                              "📅 آخر تبرع: ${donor['lastDonation']}",
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (donor['phone'] != null &&
                                        donor['phone'].toString().isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.phone,
                                            color: Colors.green),
                                        tooltip: donor['phone'],
                                        onPressed: () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  "رقم الهاتف: ${donor['phone']}"),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final isSelected = selectedBloodFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.red.shade100,
        checkmarkColor: Colors.red,
        labelStyle: TextStyle(
          color: isSelected ? Colors.red : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) {
          setState(() => selectedBloodFilter = value);
          _applyFilter();
        },
      ),
    );
  }
}
