import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/adapters.dart';
import '../../../core/constants/colors.dart';
import '../../../common/load_image.dart';

// ─── Intervalles disponibles ──────────────────────────────────────────────────

class _Interval {
  const _Interval(this.label, this.minutes);
  final String label;
  final int minutes;
}

const _kIntervals = [
  _Interval('1 minute', 1),
  _Interval('5 minutes', 5),
  _Interval('10 minutes', 10),
  _Interval('30 minutes', 30),
  _Interval('1 heure', 60),
];

// ─── Page ─────────────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Map<String, dynamic>> _user = [];
  List<Map<String, dynamic>> _capteurs = [];

  final _userBox = Hive.box('LOGGED_IN_USER');
  final _capteursBox = Hive.box('LIST_CAPTEURS');

  // Intervalles (en minutes)
  int _intervalAffichage = 5;
  int _intervalStockage = 10;
  int _intervalSync = 30;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCapteurs();
  }

  void _loadUser() {
    final data =
        _userBox.keys.map((key) {
          final item = _userBox.get(key);
          return {
            'key': key,
            'uuid_user': item['uuid_user'],
            'user_name': item['user_name'],
            'user_surname': item['user_surname'],
            'user_phone': item['user_phone'],
            'user_can_param': item['user_can_param'],
            'user_can_report': item['user_can_report'],
            'user_can_print': item['user_can_print'],
            'user_can_stor': item['user_can_stor'],
            'interval_affichage': item['interval_affichage'],
            'interval_stockage': item['interval_stockage'],
            'interval_sync': item['interval_sync'],
          };
        }).toList();

    final users = data.reversed.toList();
    if (users.isNotEmpty) {
      final u = users.first;
      _intervalAffichage =
          int.tryParse(u['interval_affichage']?.toString() ?? '') ?? 5;
      _intervalStockage =
          int.tryParse(u['interval_stockage']?.toString() ?? '') ?? 10;
      _intervalSync = int.tryParse(u['interval_sync']?.toString() ?? '') ?? 30;
    }

    setState(() => _user = users);
  }

  void _loadCapteurs() {
    final data =
        _capteursBox.keys.map((key) {
          final item = _capteursBox.get(key);
          return {
            'key': key,
            'MacAddrs': item['MacAddrs'],
            'Name': item['Name'],
            'Type': item['Type'],
            'RemoteAlert': item['RemoteAlert'],
            'Option_stockage': item['Option_stockage'],
            'interval_stockage': item['interval_stockage'],
          };
        }).toList();
    setState(() => _capteurs = data.reversed.toList());
  }

  Map<String, dynamic> get _userInfo => _user.isNotEmpty ? _user.first : {};

  // ─── Persistance ──────────────────────────────────────────────────────────────

  void _saveInterval(String hiveKey, int value) {
    if (_userBox.isEmpty) return;
    final key = _userBox.keys.first;
    final item = _userBox.get(key);
    final updated = Map<dynamic, dynamic>.from(item as Map);
    updated[hiveKey] = value.toString();
    _userBox.put(key, updated);
    print(_userBox.getAt(0));
  }

  // ─── Sélecteur bottom-sheet ───────────────────────────────────────────────────

  Future<void> _pickInterval({
    required String title,
    required IconData icon,
    required Color color,
    required int current,
    required ValueChanged<int> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => _IntervalPicker(
            title: title,
            icon: icon,
            color: color,
            current: current,
            onSelected: (v) {
              onSelected(v);
              Navigator.pop(ctx);
            },
          ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_user.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildInfoCard()),
          SliverToBoxAdapter(child: _buildParamsCard()),
          SliverToBoxAdapter(child: _buildSensorsHeader()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildSensorCard(i),
              childCount: _capteurs.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  // ─── SliverAppBar ─────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context) {
    final name =
        '${_userInfo["user_name"] ?? ''} ${_userInfo["user_surname"] ?? ''}'
            .trim();
    final phone = _userInfo['user_phone']?.toString() ?? '';

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colours.app_main,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Profil',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colours.dark_app_main,
                Colours.app_main,
                Colours.gradient_blue,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 56),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const ClipOval(
                  child: LoadAssetImage(
                    'profile/icon_avatar.png',
                    width: 76,
                    height: 76,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name.isEmpty ? 'Utilisateur' : name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 12,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    phone.isNotEmpty ? phone : 'Pas de téléphone',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Carte infos + permissions ────────────────────────────────────────────────

  Widget _buildInfoCard() {
    final canParam = _userInfo['user_can_param'] == '1';
    final canReport = _userInfo['user_can_report'] == '1';
    final canPrint = _userInfo['user_can_print'] == '1';
    final canStor = _userInfo['user_can_stor'] == '1';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colours.shadow_blue,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colours.app_main,
              ),
              const SizedBox(width: 6),
              const Text(
                "Pas d'adresse",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          if (canParam || canReport || canPrint || canStor) ...[
            const SizedBox(height: 14),
            const Text(
              'Autorisations',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canParam)
                  _PermBadge(label: 'Paramétrage', icon: Icons.tune_rounded),
                if (canReport)
                  _PermBadge(label: 'Rapports', icon: Icons.bar_chart_rounded),
                if (canPrint)
                  _PermBadge(label: 'Impression', icon: Icons.print_outlined),
                if (canStor)
                  _PermBadge(label: 'Stockage', icon: Icons.storage_outlined),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Carte paramètres intervalles ─────────────────────────────────────────────

  Widget _buildParamsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colours.shadow_blue,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colours.app_main.withValues(alpha: 0.06),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colours.app_main.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Colours.app_main,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Paramètres des intervalles',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F4FF)),

          // ── Affichage ─────────────────────────────────────────────────────
          _buildIntervalRow(
            label: 'Affichage',
            subtitle: 'Rafraîchissement écran',
            icon: Icons.monitor_rounded,
            color: Colours.app_main,
            current: _intervalAffichage,
            onTap:
                () => _pickInterval(
                  title: 'Intervalle Affichage',
                  icon: Icons.monitor_rounded,
                  color: Colours.app_main,
                  current: _intervalAffichage,
                  onSelected: (v) {
                    setState(() => _intervalAffichage = v);
                    _saveInterval('interval_affichage', v);
                  },
                ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F4FF)),
          ),

          // ── Stockage ──────────────────────────────────────────────────────
          _buildIntervalRow(
            label: 'Stockage',
            subtitle: 'Enregistrement local',
            icon: Icons.storage_rounded,
            color: const Color(0xFF8B5CF6),
            current: _intervalStockage,
            onTap:
                () => _pickInterval(
                  title: 'Intervalle Stockage',
                  icon: Icons.storage_rounded,
                  color: const Color(0xFF8B5CF6),
                  current: _intervalStockage,
                  onSelected: (v) {
                    setState(() => _intervalStockage = v);
                    _saveInterval('interval_stockage', v);
                  },
                ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F4FF)),
          ),

          // ── Synchronisation ───────────────────────────────────────────────
          _buildIntervalRow(
            label: 'Synchronisation',
            subtitle: 'Envoi vers le serveur',
            icon: Icons.sync_rounded,
            color: const Color(0xFF059669),
            current: _intervalSync,
            onTap: () {
              _pickInterval(
                title: 'Intervalle Synchronisation',
                icon: Icons.sync_rounded,
                color: const Color(0xFF059669),
                current: _intervalSync,
                onSelected: (v) {
                  setState(() => _intervalSync = v);
                  _saveInterval('interval_sync', v);
                },
              );
            },
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildIntervalRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int current,
    required VoidCallback onTap,
  }) {
    final intervalLabel =
        _kIntervals
            .firstWhere(
              (i) => i.minutes == current,
              orElse: () => _Interval('$current min', current),
            )
            .label;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icône
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            // Label + sous-titre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Valeur sélectionnée
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    intervalLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded, size: 14, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header capteurs ──────────────────────────────────────────────────────────

  Widget _buildSensorsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Capteurs autorisés',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colours.app_main.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colours.app_main.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${_capteurs.length} capteurs',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colours.app_main,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Carte capteur ────────────────────────────────────────────────────────────

  Widget _buildSensorCard(int index) {
    final sensor = _capteurs[index];
    final type = sensor['Type']?.toString() ?? '';
    final name = sensor['Name']?.toString() ?? '';
    final mac = sensor['MacAddrs']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colours.shadow_blue,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LoadAssetImage('profile/$type.jpg', width: 46, height: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  mac,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colours.app_main.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: Colours.app_main.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'T$type',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colours.app_main,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom-sheet sélecteur ───────────────────────────────────────────────────

class _IntervalPicker extends StatelessWidget {
  const _IntervalPicker({
    required this.title,
    required this.icon,
    required this.color,
    required this.current,
    required this.onSelected,
  });

  final String title;
  final IconData icon;
  final Color color;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Titre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),

          // Liste des options
          ..._kIntervals.map((interval) {
            final selected = interval.minutes == current;
            return InkWell(
              onTap: () => onSelected(interval.minutes),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                color:
                    selected
                        ? color.withValues(alpha: 0.05)
                        : Colors.transparent,
                child: Row(
                  children: [
                    // Icône horloge avec valeur
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? color.withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          interval.minutes < 60 ? '${interval.minutes}m' : '1h',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected ? color : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        interval.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? color : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      )
                    else
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ─── Permission badge ─────────────────────────────────────────────────────────

class _PermBadge extends StatelessWidget {
  const _PermBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colours.app_main.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colours.app_main.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colours.app_main),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colours.app_main,
            ),
          ),
        ],
      ),
    );
  }
}
