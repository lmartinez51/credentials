import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class DeviceStatusCard extends StatelessWidget {
  final BleService bleService;

  const DeviceStatusCard({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    final isConnected = bleService.selectedDevice != null;
    return GlassCard(
      gradientStart: isConnected ? AppTheme.successColor.withValues(alpha: 0.3) : AppTheme.errorColor.withValues(alpha: 0.3),
      gradientEnd: isConnected ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.errorColor.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isConnected ? AppTheme.successColor.withValues(alpha: 0.4) : AppTheme.errorColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        isConnected ? 'CONECTADO' : 'DESCONECTADO',
                        style: TextStyle(
                          color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isConnected ? 'Dispositivo Activo' : 'Sin Dispositivo',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isConnected) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bleService.selectedDevice!.name.isNotEmpty
                              ? bleService.selectedDevice!.name
                              : 'Dispositivo sin nombre',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28.0),
                    child: Text(
                      bleService.selectedDevice!.id,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontFamily: 'monospace'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
                  _buildCharacteristicStatus('WiFi', bleService.wifiCredsChar != null),
                  _buildCharacteristicStatus('API Key', bleService.apiKeyChar != null),
                  _buildCharacteristicStatus('Comandos', bleService.sysCmdChar != null),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCharacteristicStatus(String name, bool found) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            found ? Icons.check_circle : Icons.cancel,
            color: found ? AppTheme.successColor : AppTheme.errorColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            '$name: ',
            style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
          ),
          Text(
            found ? "Disponible" : "No disponible",
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class SearchCard extends StatelessWidget {
  final BleService bleService;
  final Animation<double> animation;
  final VoidCallback onScanPressed;

  const SearchCard({
    super.key,
    required this.bleService,
    required this.animation,
    required this.onScanPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (bleService.selectedDevice != null) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.radar, color: AppTheme.primaryAccent, size: 26),
              ),
              const SizedBox(width: 16),
              const Text(
                'Buscar AI Chatbots',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (bleService.discoveredDevices.isNotEmpty && !bleService.isScanning) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.successColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${bleService.discoveredDevices.length} dispositivo(s) encontrado(s). Presiona buscar para actualizar.',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            bleService.isScanning
                ? 'Escaneando dispositivos cercanos...'
                : 'Encuentra y configura tu ESP32-S3 fácilmente.',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade400, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: bleService.isScanning ? null : onScanPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: bleService.isScanning ? Colors.grey.shade800 : AppTheme.primaryAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                shadowColor: AppTheme.primaryAccent.withValues(alpha: 0.5),
                elevation: bleService.isScanning ? 0 : 8,
              ),
              icon: bleService.isScanning
                  ? AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: animation.value * 2 * 3.14159,
                          child: const Icon(Icons.refresh, size: 24),
                        );
                      },
                    )
                  : Icon(
                      bleService.discoveredDevices.isEmpty ? Icons.bluetooth_searching : Icons.refresh,
                      size: 24,
                    ),
              label: Text(
                bleService.isScanning
                    ? 'Buscando...'
                    : bleService.discoveredDevices.isEmpty
                        ? 'Iniciar Búsqueda'
                        : 'Buscar Nuevamente',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceListCard extends StatelessWidget {
  final BleService bleService;

  const DeviceListCard({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    if (bleService.selectedDevice != null || bleService.discoveredDevices.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.all(0), // Handled inside
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.devices_other, color: Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Dispositivos Encontrados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primaryAccent, Colors.blueAccent]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    '${bleService.discoveredDevices.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'Selecciona un dispositivo para conectarte:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: bleService.discoveredDevices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final device = bleService.discoveredDevices[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: bleService.isConnecting ? null : () => bleService.connectToDevice(device),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bluetooth, color: AppTheme.primaryAccent, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name.isNotEmpty ? device.name : 'Dispositivo Desconocido',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  device.id,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              bleService.isConnecting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.link, color: AppTheme.primaryAccent, size: 20),
                                    ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.signal_cellular_alt, size: 14, color: _getSignalColor(device.rssi)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${device.rssi} dBm',
                                    style: TextStyle(fontSize: 12, color: _getSignalColor(device.rssi), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi > -50) return AppTheme.successColor;
    if (rssi > -70) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
