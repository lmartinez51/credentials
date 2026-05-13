import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/device_cards.dart';
import '../widgets/form_cards.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final BleService _bleService = BleService();
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _bleService.addListener(() {
      if (mounted) setState(() {});
    });

    _bleService.onMessage = (message) {
      if (mounted) _showSnackBar(message.text, isError: message.isError);
    };

    _bleService.onBluetoothDisabled = () {
      if (mounted) _showBluetoothDisabledDialog();
    };

    _bleService.onBluetoothOff = () {
      if (mounted) _showBluetoothOffDialog();
    };
  }

  void _showBluetoothOffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: AppTheme.errorColor, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Bluetooth Desactivado')),
          ],
        ),
        content: const Text('Para buscar dispositivos, necesitas activar el Bluetooth.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showBluetoothDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Bluetooth Desconectado')),
          ],
        ),
        content: const Text('El Bluetooth se ha desactivado. La conexión con el dispositivo se ha perdido.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _scanForDevices() {
    _animationController.repeat();
    _bleService.scanForDevices().then((_) {
      if (mounted) {
        _animationController.stop();
        _animationController.reset();
      }
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Future<void> _closeApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
            SizedBox(width: 12),
            Text('Confirmar salida'),
          ],
        ),
        content: const Text('¿Estás seguro que deseas cerrar la aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _bleService.dispose();
      _animationController.dispose();
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _bleService.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundStart,
              AppTheme.backgroundEnd,
            ],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryAccent.withValues(alpha: 0.8),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.bluetooth,
                          size: 26,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Bridge',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.power_settings_new),
                  tooltip: 'Cerrar aplicación',
                  onPressed: _closeApp,
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _bleService.selectedDevice != null
                        ? DeviceStatusCard(bleService: _bleService)
                        : SearchCard(
                            bleService: _bleService,
                            animation: _animation,
                            onScanPressed: _scanForDevices,
                          ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: DeviceListCard(bleService: _bleService),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: WifiConfigCard(bleService: _bleService),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: ApiKeyConfigCard(bleService: _bleService),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AdvancedOptionsCard(bleService: _bleService),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
