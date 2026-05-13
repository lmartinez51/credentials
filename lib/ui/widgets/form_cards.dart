import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../utils/ble_constants.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class WifiConfigCard extends StatefulWidget {
  final BleService bleService;

  const WifiConfigCard({super.key, required this.bleService});

  @override
  State<WifiConfigCard> createState() => _WifiConfigCardState();
}

class _WifiConfigCardState extends State<WifiConfigCard> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  bool showPassword = false;

  bool get isWifiFormValid =>
      ssidController.text.isNotEmpty &&
      passwordController.text.length >= 4 &&
      widget.bleService.selectedDevice != null &&
      widget.bleService.wifiCredsChar != null;

  @override
  void dispose() {
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void sendWifiCommand() {
    if (!isWifiFormValid) return;
    
    final ssid = ssidController.text.trim();
    final password = passwordController.text.trim();
    final cmd = '$ssid $password';

    widget.bleService.executeCommand(
      characteristic: widget.bleService.wifiCredsChar!,
      payload: cmd,
      successMessage: '✅ Credenciales enviadas. El dispositivo se reiniciará...',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bleService.selectedDevice == null || widget.bleService.wifiCredsChar == null) {
      return const SizedBox.shrink();
    }
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi, color: AppTheme.successColor, size: 24),
              ),
              const SizedBox(width: 16),
              const Text('Configuración WiFi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: ssidController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'SSID WiFi',
              hintText: 'Nombre de tu red',
              prefixIcon: Icon(Icons.router, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: !showPassword,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Contraseña WiFi',
              hintText: 'Mínimo 4 caracteres',
              prefixIcon: const Icon(Icons.lock, color: Colors.grey),
              suffixIcon: IconButton(
                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => setState(() => showPassword = !showPassword),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: (isWifiFormValid && !widget.bleService.isSending) ? sendWifiCommand : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isWifiFormValid ? AppTheme.successColor : Colors.grey.shade800,
                elevation: isWifiFormValid ? 8 : 0,
                shadowColor: AppTheme.successColor.withValues(alpha: 0.5),
              ),
              icon: widget.bleService.isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(
                widget.bleService.isSending ? 'Enviando...' : 'Enviar Credenciales',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ApiKeyConfigCard extends StatefulWidget {
  final BleService bleService;

  const ApiKeyConfigCard({super.key, required this.bleService});

  @override
  State<ApiKeyConfigCard> createState() => _ApiKeyConfigCardState();
}

class _ApiKeyConfigCardState extends State<ApiKeyConfigCard> {
  final apiKeyController = TextEditingController();
  bool showApiKey = false;

  bool get isApiKeyFormatValid => apiKeyController.text.trim().length >= 20;

  bool get isApiKeyFormValid =>
      apiKeyController.text.isNotEmpty &&
      isApiKeyFormatValid &&
      widget.bleService.selectedDevice != null &&
      widget.bleService.apiKeyChar != null;

  @override
  void dispose() {
    apiKeyController.dispose();
    super.dispose();
  }

  void sendApiKeyCommand() {
    if (!isApiKeyFormValid) return;
    
    final apiKey = apiKeyController.text.trim();
    widget.bleService.executeCommand(
      characteristic: widget.bleService.apiKeyChar!,
      payload: apiKey,
      successMessage: '✅ API Key enviada. El dispositivo se reiniciará...',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bleService.selectedDevice == null || widget.bleService.apiKeyChar == null) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.vpn_key, color: AppTheme.secondaryAccent, size: 24),
              ),
              const SizedBox(width: 16),
              const Text('Configuración API Key', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ingresa tu API Key para habilitar funciones de IA.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: apiKeyController,
            obscureText: !showApiKey,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'OpenAI API Key',
              hintText: 'Ej: sk-proj-xxxxxxxxxxxxx',
              prefixIcon: const Icon(Icons.key, color: Colors.grey),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (apiKeyController.text.isNotEmpty)
                    Icon(
                      isApiKeyFormatValid ? Icons.check_circle : Icons.error_outline,
                      color: isApiKeyFormatValid ? AppTheme.successColor : AppTheme.errorColor,
                      size: 20,
                    ),
                  IconButton(
                    icon: Icon(showApiKey ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => showApiKey = !showApiKey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: (isApiKeyFormValid && !widget.bleService.isSending) ? sendApiKeyCommand : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isApiKeyFormValid ? AppTheme.secondaryAccent : Colors.grey.shade800,
                elevation: isApiKeyFormValid ? 8 : 0,
                shadowColor: AppTheme.secondaryAccent.withValues(alpha: 0.5),
              ),
              icon: widget.bleService.isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 24),
              label: Text(
                widget.bleService.isSending ? 'Enviando...' : 'Enviar API Key',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdvancedOptionsCard extends StatelessWidget {
  final BleService bleService;

  const AdvancedOptionsCard({super.key, required this.bleService});

  Future<void> _confirmAndErase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar borrado', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de borrar TODAS las credenciales del dispositivo?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (bleService.sysCmdChar != null) {
      bleService.executeCommand(
        characteristic: bleService.sysCmdChar!,
        payload: BleConstants.cmdEraseNvs,
        successMessage: '✅ NVS borrada. El dispositivo se reiniciará...',
        withResponse: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (bleService.selectedDevice == null || bleService.sysCmdChar == null) {
      return const SizedBox.shrink();
    }
    
    return GlassCard(
      gradientStart: AppTheme.errorColor.withValues(alpha: 0.15),
      gradientEnd: AppTheme.errorColor.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 24),
              ),
              const SizedBox(width: 16),
              const Text('Opciones Avanzadas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
            ),
            child: const Column(
              children: [
                Icon(Icons.dangerous, color: AppTheme.errorColor, size: 28),
                SizedBox(height: 8),
                Text(
                  'Esta operación borrará permanentemente todas las credenciales WiFi y API Keys almacenadas.',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shadowColor: AppTheme.errorColor.withValues(alpha: 0.5),
              ),
              icon: bleService.isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_forever, size: 24),
              label: Text(
                bleService.isSending ? 'Borrando...' : 'Borrar Credenciales',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: bleService.isSending ? null : () => _confirmAndErase(context),
            ),
          ),
        ],
      ),
    );
  }
}
