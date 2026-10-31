import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Ciftlik360App());
}

class Ciftlik360App extends StatelessWidget {
  const Ciftlik360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Çiftlik 360',
      debugShowCheckedModeBanner: false,
      // TÜRKÇE DİL VE TAKVİM AYARLARI
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF15803D), // Doğal Zümrüt Yeşili
          primary: const Color(0xFF15803D),
          surface: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF15803D),
          foregroundColor: Colors.white,
          elevation: 1,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          color: Colors.white,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// Yaş Hesaplama Yardımcısı (Tam Yaş: Yıl, Ay, Gün)
String getExactAge(Animal a) {
  if (a.birthDate != null && a.birthDate!.isNotEmpty) {
    try {
      final bDate = DateTime.parse(a.birthDate!);
      final now = DateTime.now();
      int years = now.year - bDate.year;
      int months = now.month - bDate.month;
      int days = now.day - bDate.day;

      if (days < 0) {
        months -= 1;
      }
      if (months < 0) {
        years -= 1;
        months += 12;
      }

      if (years > 0) {
        if (months > 0) {
          return '$years Yaş $months Aylık';
        } else {
          return '$years Yaşında';
        }
      } else if (months > 0) {
        return '$months Aylık';
      } else {
        final totalDays = now.difference(bDate).inDays;
        return '$totalDays Günlük';
      }
    } catch (_) {}
  }
  if (a.age != null && a.age!.isNotEmpty) {
    return a.age!;
  }
  return 'Belirtilmedi';
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    AnimalsPage(),
    MilkPage(),
    FinancePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDCFCE7),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Color(0xFF15803D)),
              label: 'Panel',
            ),
            NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(Icons.pets, color: Color(0xFF15803D)),
              label: 'Hayvanlar',
            ),
            NavigationDestination(
              icon: Icon(Icons.water_drop_outlined),
              selectedIcon: Icon(Icons.water_drop, color: Color(0xFF15803D)),
              label: 'Süt',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF15803D)),
              label: 'Kasa',
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 1. PANEL (DASHBOARD)
// =========================================================================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _totalAnimals = 0;
  int _femaleCount = 0;
  int _maleCount = 0;
  int _pregnantCount = 0;
  double _todaySabah = 0.0;
  double _todayAksam = 0.0;
  double _monthlyIncome = 0.0;
  double _monthlyExpense = 0.0;
  List<Animal> _upcomingBirths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = DBHelper.instance;
    final animals = await db.getAnimals();
    final milkSummary = await db.getTodayMilkSummary();
    final finSummary = await db.getMonthlyFinanceSummary();

    final now = DateTime.now();
    final births = animals.where((a) {
      if (!a.isPregnant || a.estBirthDate == null) return false;
      final bDate = DateTime.tryParse(a.estBirthDate!);
      if (bDate == null) return false;
      final diff = bDate.difference(now).inDays;
      return diff <= 30;
    }).toList();

    if (mounted) {
      setState(() {
        _totalAnimals = animals.length;
        _femaleCount = animals.where((a) => a.gender == 'Dişi').length;
        _maleCount = animals.where((a) => a.gender == 'Erkek').length;
        _pregnantCount = animals.where((a) => a.isPregnant).length;
        _upcomingBirths = births;

        _todaySabah = milkSummary['sabah'] ?? 0.0;
        _todayAksam = milkSummary['aksam'] ?? 0.0;

        _monthlyIncome = finSummary['income'] ?? 0.0;
        _monthlyExpense = finSummary['expense'] ?? 0.0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double netProfit = _monthlyIncome - _monthlyExpense;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🌾', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Çiftlik 360', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text('Dahili Hafıza & Yerel Takip', style: TextStyle(fontSize: 11, color: Color(0xFFDCFCE7))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Yedekleme & Geri Yükle',
            onPressed: () => _showBackupDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // DOĞUM YAKLAŞANLAR UYARISI
                  if (_upcomingBirths.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          const Text('🤰', style: TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Yaklaşan Doğum (${_upcomingBirths.length} İnek)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade900),
                                ),
                                Text(
                                  '${_upcomingBirths.first.name} (${_upcomingBirths.first.tagNo}) doğum tarihi yaklaştı (${_upcomingBirths.first.estBirthDate}).',
                                  style: TextStyle(fontSize: 12, color: Colors.purple.shade800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // SÜRÜ DURUM KARTI
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('SÜRÜ DURUMU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                                child: const Text('Aktif Çiftlik', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('$_totalAnimals', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                              const SizedBox(width: 6),
                              const Text('baş hayvan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _subBadge('Dişi', '$_femaleCount', Colors.pink.shade50, Colors.pink.shade700),
                              const SizedBox(width: 8),
                              _subBadge('Erkek', '$_maleCount', Colors.blue.shade50, Colors.blue.shade700),
                              const SizedBox(width: 8),
                              _subBadge('Gebe', '$_pregnantCount', Colors.purple.shade50, Colors.purple.shade700),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // BUGÜNKÜ SÜT: GÜNEŞ & AY GÖRSELLERİ
                  const Text('BUGÜNKÜ SAĞIM ÖZETİ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Sabah Sağımı (Güneş)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFEF08A), Color(0xFFFDE047)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFACC15), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('☀️', style: TextStyle(fontSize: 28)),
                                  Text('SABAH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF854D0E))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${_todaySabah.toStringAsFixed(1)} Lt', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF713F12))),
                              const Text('Güneş Sağımı', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF854D0E))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Akşam Sağımı (Ay)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF334155), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('🌙', style: TextStyle(fontSize: 28)),
                                  Text('AKŞAM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${_todayAksam.toStringAsFixed(1)} Lt', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                              const Text('Ay Sağımı', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // KASA ÖZETİ
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('BU AYKİ KASA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                              Text(
                                '${netProfit >= 0 ? '+' : ''}${netProfit.toStringAsFixed(0)} TL Net',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: netProfit >= 0 ? const Color(0xFF15803D) : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Toplam Gelir (+)', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text('+${_monthlyIncome.toStringAsFixed(0)} TL', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Toplam Gider (-)', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text('-${_monthlyExpense.toStringAsFixed(0)} TL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _subBadge(String label, String value, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text('$label: $value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Text('☁️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Yedekleme & Geri Yükle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tüm hayvan, süt ve kasa kayıtlarınızı tek tıkla kopyalayabilir, WhatsApp kendinize veya notlarınıza kaydedebilirsiniz.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Yedek Metnini Kopyala'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
                onPressed: () async {
                  final jsonStr = await DBHelper.instance.exportBackupJson();
                  await Clipboard.setData(ClipboardData(text: jsonStr));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Yedek metni panoya kopyalandı!')),
                    );
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Yedekten Geri Yükle'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRestoreDialog(context);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📥 Yedekten Geri Yükle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Daha önce kopyaladığınız yedek metnini buraya yapıştırın:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Yedek metnini buraya yapıştırın...', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
            onPressed: () async {
              if (textCtrl.text.trim().isEmpty) return;
              final ok = await DBHelper.instance.restoreFromBackupJson(textCtrl.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Tüm veriler başarıyla geri yüklendi!' : 'Hata: Geçersiz yedek metni!')),
                );
                _loadStats();
              }
            },
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 2. HAYVANLAR SAYFASI - Tam Yaş, Türkçe Takvim, Gebe Kaldı Butonu
// =========================================================================
class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  List<Animal> _animals = [];
  String _genderFilter = 'Tümü';

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  Future<void> _loadAnimals() async {
    final list = await DBHelper.instance.getAnimals(genderFilter: _genderFilter);
    setState(() => _animals = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hayvanlarım', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // ÜST BUTONLAR
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text('YENİ HAYVAN EKLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    onPressed: () => _showAddAnimalDialog(context),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Filtrele: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(width: 6),
                    _genderChip('Tümü'),
                    const SizedBox(width: 6),
                    _genderChip('Dişi'),
                    const SizedBox(width: 6),
                    _genderChip('Erkek'),
                  ],
                ),
              ],
            ),
          ),

          // LİSTE
          Expanded(
            child: _animals.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('🐄', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 8),
                        Text('Henüz kayıtlı hayvanınız yok.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text('Yukarıdaki "+ YENİ HAYVAN EKLE" butonuna basarak ekleyin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _animals.length,
                    itemBuilder: (ctx, i) {
                      final a = _animals[i];
                      final isFemale = a.gender == 'Dişi';
                      final exactAge = getExactAge(a);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _showAnimalDetail(context, a),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isFemale ? Colors.pink.shade50 : Colors.blue.shade50,
                                          child: Text(isFemale ? '🐄' : '🐂', style: const TextStyle(fontSize: 20)),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(a.name.isNotEmpty ? a.name : 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                            Text('Küpe No: ${a.tagNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D))),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Text('Detay →', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          tooltip: 'Hayvanı Sil',
                                          onPressed: () => _confirmDeleteAnimal(a),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    _infoPill('Cinsiyet', a.gender, isFemale ? Colors.pink.shade100 : Colors.blue.shade100, isFemale ? Colors.pink.shade800 : Colors.blue.shade800),
                                    const SizedBox(width: 6),
                                    _infoPill('Irk', a.breed, Colors.grey.shade100, Colors.black87),
                                    const SizedBox(width: 6),
                                    _infoPill('Yaş', exactAge, Colors.amber.shade50, Colors.amber.shade900),
                                  ],
                                ),

                                // GEBELİK ROZETİ (Eğer Gebe ise)
                                if (a.isPregnant) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.purple.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text('🤰', style: TextStyle(fontSize: 16)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Gebe • Tahmini Doğum: ${a.estBirthDate ?? "Tarih belirtilmedi"}',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

  Widget _genderChip(String label) {
    final isSelected = _genderFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (s) {
        setState(() => _genderFilter = label);
        _loadAnimals();
      },
      selectedColor: const Color(0xFF15803D),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  Widget _infoPill(String label, String value, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
    );
  }

  // --- HAYVANA DOKUNULDUĞUNDA AÇILAN DETAY (TAM YAŞ VE GEBE KALDI BUTONU) ---
  void _showAnimalDetail(BuildContext context, Animal a) {
    final isFemale = a.gender == 'Dişi';
    final exactAge = getExactAge(a);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isFemale ? Colors.pink.shade50 : Colors.blue.shade50,
                        child: Text(isFemale ? '🐄' : '🐂', style: const TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name.isNotEmpty ? a.name : 'İsimsiz', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text('Küpe No: ${a.tagNo}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 20),

              // BİLGİ KARTLARI
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _detailRow('Tam Yaşı:', exactAge, isBold: true),
                    const SizedBox(height: 6),
                    _detailRow('Cinsiyet:', a.gender),
                    const SizedBox(height: 6),
                    _detailRow('Irkı / Cinsi:', a.breed),
                    if (a.birthDate != null && a.birthDate!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _detailRow('Doğum Tarihi:', a.birthDate!),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // GEBELİK BÖLÜMÜ
              if (isFemale) ...[
                if (!a.isPregnant) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.favorite),
                      label: const Text('🤰 BU HAYVAN GEBE KALDI (TOHUMLANDI)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      onPressed: () async {
                        final now = DateTime.now();
                        final estBirth = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 283)));
                        final tohumDate = DateFormat('yyyy-MM-dd').format(now);

                        await DBHelper.instance.setAnimalPregnancy(
                          a.id!,
                          true,
                          inseminationDate: tohumDate,
                          estBirthDate: estBirth,
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${a.name} gebe olarak kaydedildi! Tahmini Doğum: $estBirth')),
                          );
                          _loadAnimals();
                        }
                      },
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Text('🤰', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 8),
                            Text('Bu Hayvan Şu Anda Gebe', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF581C87))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Tohumlama: ${a.inseminationDate ?? "-"} • Tahmini Doğum: ${a.estBirthDate ?? "-"}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
                          icon: const Icon(Icons.child_care),
                          label: const Text('👶 Doğurdu!'),
                          onPressed: () async {
                            await DBHelper.instance.setAnimalPregnancy(a.id!, false);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tebrikler! Doğum tamamlandı olarak güncellendi.')),
                              );
                              _loadAnimals();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: () async {
                            await DBHelper.instance.setAnimalPregnancy(a.id!, false);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              _loadAnimals();
                            }
                          },
                          child: const Text('Boş Döndü / İptal'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: isBold ? const Color(0xFF15803D) : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAnimal(Animal a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hayvanı Sil', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${a.name} (${a.tagNo}) küpeli hayvanı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await DBHelper.instance.deleteAnimal(a.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadAnimals();
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // --- YENİ HAYVAN EKLEME DİYALOĞU (TÜRKÇE TAKVİM) ---
  void _showAddAnimalDialog(BuildContext context) {
    final tagCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    DateTime? birthDate;
    String breed = 'Simental';
    String gender = 'Dişi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🐄 Yeni Hayvan Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 12),

                // Küpe No & İsim
                TextField(
                  controller: tagCtrl,
                  decoration: const InputDecoration(labelText: 'Küpe Numarası *', hintText: 'Örn: TR-001 veya 43', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'İsim / Lakap', hintText: 'Örn: Sarıkız, Kınalı', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                // Cinsiyet Seçimi
                Row(
                  children: [
                    const Text('Cinsiyeti: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Dişi ♀'),
                      selected: gender == 'Dişi',
                      onSelected: (s) => setModalState(() => gender = 'Dişi'),
                      selectedColor: Colors.pink.shade100,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Erkek ♂'),
                      selected: gender == 'Erkek',
                      onSelected: (s) => setModalState(() => gender = 'Erkek'),
                      selectedColor: Colors.blue.shade100,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Irkı & Yaşı
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: breed,
                        decoration: const InputDecoration(labelText: 'Irkı', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Simental', child: Text('Simental')),
                          DropdownMenuItem(value: 'Holstein', child: Text('Holstein')),
                          DropdownMenuItem(value: 'Montofon', child: Text('Montofon')),
                          DropdownMenuItem(value: 'Yerli Kara', child: Text('Yerli Kara')),
                          DropdownMenuItem(value: 'Angus', child: Text('Angus')),
                          DropdownMenuItem(value: 'Melez', child: Text('Melez')),
                        ],
                        onChanged: (v) => setModalState(() => breed = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Yaşı (Kolay Giriş)',
                          hintText: 'Örn: 3 Yaşında',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Doğum Tarihi (TÜRKÇE TAKVİM)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    birthDate == null ? 'Doğum Tarihi Seç (Takvimden - Türkçe)' : 'Doğum Tarihi: ${DateFormat("dd.MM.yyyy").format(birthDate!)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().subtract(const Duration(days: 365)),
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now(),
                      locale: const Locale('tr', 'TR'), // Türkçe Takvim
                      helpText: 'DOĞUM TARİHİ SEÇİN',
                      cancelText: 'İPTAL',
                      confirmText: 'TAMAM',
                    );
                    if (picked != null) {
                      setModalState(() => birthDate = picked);
                    }
                  },
                ),

                const SizedBox(height: 16),

                // KAYDET BUTONU
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (tagCtrl.text.trim().isEmpty) return;

                      await DBHelper.instance.addAnimal(Animal(
                        tagNo: tagCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        breed: breed,
                        gender: gender,
                        age: ageCtrl.text.trim().isNotEmpty ? ageCtrl.text.trim() : null,
                        birthDate: birthDate != null ? DateFormat('yyyy-MM-dd').format(birthDate!) : null,
                        isPregnant: false,
                      ));

                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAnimals();
                    },
                    child: const Text('HAYVANI SİSTEME KAYDET', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 3. SÜT SAYFASI - Sabah Sağımlarında Güneş ☀️, Akşam Sağımlarında Ay 🌙
// =========================================================================
class MilkPage extends StatefulWidget {
  const MilkPage({super.key});

  @override
  State<MilkPage> createState() => _MilkPageState();
}

class _MilkPageState extends State<MilkPage> {
  List<MilkRecord> _records = [];
  double _todaySabah = 0.0;
  double _todayAksam = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMilk();
  }

  Future<void> _loadMilk() async {
    final list = await DBHelper.instance.getMilkRecords();
    final summary = await DBHelper.instance.getTodayMilkSummary();
    setState(() {
      _records = list;
      _todaySabah = summary['sabah'] ?? 0.0;
      _todayAksam = summary['aksam'] ?? 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Süt Sağım Takibi', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SAĞIM EKLEME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // GÜNEŞ: SABAH SAĞIMI
                    Expanded(
                      child: InkWell(
                        onTap: () => _showAddMilkDialog(context, 'Sabah'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFEF08A), Color(0xFFFACC15)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEAB308), width: 1.5),
                          ),
                          child: Column(
                            children: const [
                              Text('☀️', style: TextStyle(fontSize: 34)),
                              SizedBox(height: 4),
                              Text('SABAH SAĞIMI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF713F12))),
                              Text('+ Litre Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF854D0E))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // AY: AKŞAM SAĞIMI
                    Expanded(
                      child: InkWell(
                        onTap: () => _showAddMilkDialog(context, 'Akşam'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF334155), width: 1.5),
                          ),
                          child: Column(
                            children: const [
                              Text('🌙', style: TextStyle(fontSize: 34)),
                              SizedBox(height: 4),
                              Text('AKŞAM SAĞIMI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
                              Text('+ Litre Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sağım Geçmişi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Bugün: ${(_todaySabah + _todayAksam).toStringAsFixed(1)} Lt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D))),
              ],
            ),
          ),

          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('🥛', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 8),
                        Text('Henüz süt kaydı girilmedi.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text('Yukarıdaki ☀️ Sabah veya 🌙 Akşam butonlarına dokunarak girin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _records.length,
                    itemBuilder: (ctx, i) {
                      final r = _records[i];
                      final isMorning = r.session == 'Sabah';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: isMorning ? const Color(0xFFFEF9C3) : const Color(0xFFE2E8F0),
                            child: Text(isMorning ? '☀️' : '🌙', style: const TextStyle(fontSize: 20)),
                          ),
                          title: Text(
                            '${isMorning ? "☀️ Sabah Sağımı" : "🌙 Akşam Sağımı"} (${r.animalTag})',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isMorning ? const Color(0xFF854D0E) : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(r.date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${r.liters} Lt', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF15803D))),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () async {
                                  await DBHelper.instance.deleteMilkRecord(r.id!);
                                  _loadMilk();
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

  void _showAddMilkDialog(BuildContext context, String session) {
    final literCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    final isMorning = session == 'Sabah';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isMorning ? '☀️' : '🌙', style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
                Text('$session Sağımı Girişi', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: literCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Kaç Litre Sağıldı? *', hintText: 'Örn: 25.5', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tagCtrl,
              decoration: const InputDecoration(labelText: 'İnek Küpe No (Boşsa Genel Çiftlik)', hintText: 'Örn: TR-001 veya boş bırakın', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMorning ? const Color(0xFFEAB308) : const Color(0xFF1E293B),
                  foregroundColor: isMorning ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final liters = double.tryParse(literCtrl.text);
                  if (liters == null || liters <= 0) return;

                  await DBHelper.instance.addMilkRecord(MilkRecord(
                    animalTag: tagCtrl.text.trim().isEmpty ? 'Genel Sürü' : tagCtrl.text.trim(),
                    date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    session: session,
                    liters: liters,
                  ));

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadMilk();
                },
                child: Text('$session Sütünü Kaydet', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 4. KASA (GELİR / GİDER) SAYFASI
// =========================================================================
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  List<FinanceRecord> _records = [];
  double _income = 0.0;
  double _expense = 0.0;
  DateTime _selectedMonth = DateTime.now();
  bool _showAllMonths = false;

  @override
  void initState() {
    super.initState();
    _loadFinance();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _monthTitle => DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);

  Future<void> _loadFinance() async {
    final monthFilter = _showAllMonths ? null : _monthKey;
    final list = await DBHelper.instance.getFinanceRecords(monthFilter: monthFilter);
    final summary = await DBHelper.instance.getMonthlyFinanceSummary(monthFilter: monthFilter);
    setState(() {
      _records = list;
      _income = summary['income'] ?? 0.0;
      _expense = summary['expense'] ?? 0.0;
    });
  }

  void _previousMonth() {
    setState(() {
      _showAllMonths = false;
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _loadFinance();
  }

  void _nextMonth() {
    setState(() {
      _showAllMonths = false;
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _loadFinance();
  }

  @override
  Widget build(BuildContext context) {
    final double netProfit = _income - _expense;

    return Scaffold(
      appBar: AppBar(title: const Text('Kasa & Geçmiş Hesaplar', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          // AY SEÇİCİ ÇUBUK (Önceki Ay <-> Sonraki Ay)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28),
                  tooltip: 'Önceki Ay',
                  onPressed: _previousMonth,
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _showAllMonths = !_showAllMonths);
                    _loadFinance();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 18, color: Color(0xFF15803D)),
                      const SizedBox(width: 6),
                      Text(
                        _showAllMonths ? 'Tüm Zamanlar (Toplam)' : _monthTitle.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 28),
                  tooltip: 'Sonraki Ay',
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ÜST KISIM: 2 BÜYÜK BUTON (+ GELİR EKLE ve + GİDER EKLE)
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('GELİR EKLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        onPressed: () => _showAddTransactionDialog(context, 'Gelir'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.remove),
                        label: const Text('GİDER EKLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        onPressed: () => _showAddTransactionDialog(context, 'Gider'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // SEÇİLEN AYIN HESAP ÖZETİ
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_showAllMonths ? 'Toplam Gelir' : ' Gelir', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                            Text('+ TL', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_showAllMonths ? 'Toplam Gider' : ' Gider', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                            Text('- TL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: netProfit >= 0 ? const Color(0xFFF0FDF4) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: netProfit >= 0 ? const Color(0xFFBBF7D0) : Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _showAllMonths ? 'Tüm Zamanlar Net Durum:' : ' Net Kâr/Zarar:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: netProfit >= 0 ? const Color(0xFF166534) : Colors.red.shade900),
                      ),
                      Text(
                        ' TL',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: netProfit >= 0 ? const Color(0xFF166534) : Colors.red.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showAllMonths ? 'Tüm Kasa Hareketleri' : ' Hareketleri',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(' işlem', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💰', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text(' ayında kayıtlı kasa hareketi yok.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const Text('Önceki veya sonraki aylara bakmak için yukarıdaki oklara basın.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _records.length,
                    itemBuilder: (ctx, i) {
                      final r = _records[i];
                      final isIncome = r.type == 'Gelir';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? const Color(0xFFDCFCE7) : Colors.red.shade50,
                            child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? const Color(0xFF15803D) : Colors.red.shade700, size: 20),
                          ),
                          title: Text(r.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(r.date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ' TL',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isIncome ? const Color(0xFF15803D) : Colors.red.shade700),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  await DBHelper.instance.deleteFinanceRecord(r.id!);
                                  _loadFinance();
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

  void _showAddTransactionDialog(BuildContext context, String type) {
    final catCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final isIncome = type == 'Gelir';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isIncome ? '🟢 Yeni Gelir Ekle' : '🔴 Yeni Gider Ekle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TextField(
                controller: catCtrl,
                decoration: InputDecoration(
                  labelText: isIncome ? 'Gelir Türü (Örn: Süt Satışı, Buzağı Satışı)' : 'Gider Türü (Örn: Yem, Veteriner, Mazot)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tutar (TL) *', hintText: '0.00', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  minimumSize: const Size(double.infinity, 44),
                ),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('Tarih: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    locale: const Locale('tr', 'TR'),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isIncome ? const Color(0xFF15803D) : Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text);
                    if (amt == null || amt <= 0 || catCtrl.text.trim().isEmpty) return;

                    await DBHelper.instance.addFinanceRecord(FinanceRecord(
                      type: type,
                      category: catCtrl.text.trim(),
                      amount: amt,
                      date: DateFormat('yyyy-MM-dd').format(selectedDate),
                    ));

                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadFinance();
                  },
                  child: Text('Kasaya  Kaydet', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
