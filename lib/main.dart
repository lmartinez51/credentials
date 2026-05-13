import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AIBridge',
      home: const WifiConfigPage(),
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1565C0),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1A1A1A),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class WifiConfigPage extends StatefulWidget {
  const WifiConfigPage({super.key});

  @override
  State<WifiConfigPage> createState() => _WifiConfigPageState();
}

class _WifiConfigPageState extends State<WifiConfigPage>
    with SingleTickerProviderStateMixin {
  final flutterReactiveBle = FlutterReactiveBle();
  DiscoveredDevice? selectedDevice;
  QualifiedCharacteristic? _wifiCredsChar;
  QualifiedCharacteristic? _apiKeyChar;
  QualifiedCharacteristic? _sysCmdChar;

  // Controllers - AGREGADO: apiKeyController
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  final apiKeyController = TextEditingController(); // NUEVO

  StreamSubscription<DiscoveredDevice>? scanSub;
  StreamSubscription<ConnectionStateUpdate>? connectionSub;
  StreamSubscription<BleStatus>? bleStatusSub;
  final List<DiscoveredDevice> discoveredDevices = [];
  int reconnectAttempts = 0;
  final int maxReconnectAttempts = 3;

  bool showPassword = false;
  bool showApiKey = false; // NUEVO
  bool isScanning = false;
  bool isConnecting = false;
  bool isSending = false;
  bool isSendingWifi = false;
  bool isSendingApiKey = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  // MODIFICADO: Validación actualizada
  bool get isWifiFormValid =>
      ssidController.text.isNotEmpty &&
      passwordController.text.length >= 4 &&
      selectedDevice != null &&
      _wifiCredsChar != null;

  bool get isApiKeyFormatValid {
    final key = apiKeyController.text.trim();
    // Validación básica: mínimo 20 caracteres
    return key.length >= 20;
  }

// Modificar isApiKeyFormValid:
  bool get isApiKeyFormValid =>
      apiKeyController.text.isNotEmpty &&
      isApiKeyFormatValid && // ⬅ Agregar esta línea
      selectedDevice != null &&
      _apiKeyChar != null;

  @override
  void initState() {
    super.initState();
    ssidController.addListener(() => setState(() {}));
    passwordController.addListener(() => setState(() {}));
    apiKeyController.addListener(() => setState(() {})); // NUEVO

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeBleStatusListener();
  }

  void _initializeBleStatusListener() {
    bleStatusSub = flutterReactiveBle.statusStream.listen((status) {
      debugPrint('BLE Status changed: $status');
      if (status != BleStatus.ready && (isScanning || selectedDevice != null)) {
        _handleBluetoothDisabled();
      }
    });
  }

  void _handleBluetoothDisabled() {
    if (isScanning) _stopScanning();
    if (selectedDevice != null) _disconnectDevice();
    _showBluetoothDisabledDialog();
  }

  void _stopScanning() {
    if (!mounted) return;
    setState(() => isScanning = false);
    _animationController.stop();
    _animationController.reset();
    scanSub?.cancel();
    discoveredDevices.clear();
  }

  void _disconnectDevice() {
    connectionSub?.cancel();
    setState(() {
      selectedDevice = null;
      _wifiCredsChar = null;
      _apiKeyChar = null;
      _sysCmdChar = null;
      isConnecting = false;
    });
  }

// --- Helper para pedir permisos bluetooth (Android 12+ y anteriores) ---
  Future<bool> _requestBluetoothPermissions() async {
    // Intentamos pedir permisos modernos primero
    try {
      // Android 12+ puede necesitar bluetoothScan / bluetoothConnect / bluetoothAdvertise
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission
            .locationWhenInUse, // fallback para Android < 12 / ubicación si corresponde
      ].request();

      // Consideramos permisos aceptados si alguno de los permisos bluetooth principales es granted
      bool granted = (statuses[Permission.bluetooth]?.isGranted ?? false) ||
          (statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
          (statuses[Permission.bluetoothConnect]?.isGranted ?? false) ||
          (statuses[Permission.locationWhenInUse]?.isGranted ?? false);

      return granted;
    } catch (e) {
      debugPrint('[PERM] Error pidiendo permisos: $e');
      return false;
    }
  }

// --- Versión robusta de _checkBluetoothStatus ---
  Future<bool> _checkBluetoothStatus() async {
    // Obtenemos el estado actual
    BleStatus status;
    try {
      status = await flutterReactiveBle.statusStream.first;
    } catch (e) {
      // Si por alguna razón falla la lectura, tratamos como unknown y seguimos
      debugPrint('[BLE] Error leyendo statusStream.first: $e');
      status = BleStatus.unknown;
    }

    debugPrint('Current BLE Status: $status');
    if (!mounted) return false;

    switch (status) {
      case BleStatus.ready:
        return true;

      case BleStatus.poweredOff:
        // El bluetooth está apagado — mostramos diálogo inmediato
        _showBluetoothOffDialog();
        return false;

      case BleStatus.unsupported:
        _showSnackBar('Bluetooth no soportado en este dispositivo.',
            isError: true);
        return false;

      case BleStatus.locationServicesDisabled:
        _showSnackBar('Los servicios de ubicación están desactivados.',
            isError: true);
        return false;

      case BleStatus.unauthorized:
      case BleStatus.unknown:
        // Estado transitorio: solicitar permisos y/o esperar el siguiente evento
        debugPrint(
            '[BLE] Estado transitorio ($status). Solicitando permisos y esperando actualización...');
        // 1) Pedimos permisos al usuario (si aplica)
        bool permsGranted = await _requestBluetoothPermissions();

        if (!permsGranted) {
          // Si el usuario negó permisos AL INSTANTE, mostramos un mensaje claro y no un "estado desconocido"
          _showSnackBar(
              'Permisos Bluetooth no concedidos. No es posible buscar dispositivos.',
              isError: true);
          return false;
        }

        // 2) Esperamos el siguiente evento del statusStream (con timeout)
        try {
          // Espera hasta 3 segundos por un nuevo estado distinto al actual
          final nextStatus = await flutterReactiveBle.statusStream
              .firstWhere((s) => s != status)
              .timeout(const Duration(seconds: 3));
          debugPrint(
              '[BLE] Nuevo estado después de pedir permisos: $nextStatus');

          // Re-evaluamos recursivamente con el nuevo estado
          // para evitar duplicar lógica; como ya pedimos permisos y hubo cambio,
          // volverá al case correspondiente.
          // Protección: evitar recursión infinita, pero aquí es seguro (un paso más).
          if (!mounted) return false;
          switch (nextStatus) {
            case BleStatus.ready:
              return true;
            case BleStatus.poweredOff:
              _showBluetoothOffDialog();
              return false;
            case BleStatus.unsupported:
              _showSnackBar('Bluetooth no soportado en este dispositivo.',
                  isError: true);
              return false;
            case BleStatus.locationServicesDisabled:
              _showSnackBar('Los servicios de ubicación están desactivados.',
                  isError: true);
              return false;
            default:
              _showSnackBar('Estado de Bluetooth no válido: $nextStatus',
                  isError: true);
              return false;
          }
        } catch (e) {
          // Timeout o error al esperar. En lugar de mostrar un mensaje de error alarmante,
          // mostramos una notificación suave indicando que no se pudo determinar el estado.
          debugPrint('[BLE] Timeout esperando nueva señal de estado: $e');
          // No mostrar el mensaje de "Estado desconocido: ..." que confunde al usuario.
          _showSnackBar(
              'Esperando permisos/estado de Bluetooth. Intenta nuevamente.',
              isError: false);
          return false;
        }
    }
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
            Icon(Icons.bluetooth_disabled, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Bluetooth Desactivado')),
          ],
        ),
        content: const Text(
            'Para buscar dispositivos, necesitas activar el Bluetooth.'),
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
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Bluetooth Desconectado')),
          ],
        ),
        content: const Text(
            'El Bluetooth se ha desactivado. La conexión con el dispositivo se ha perdido.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<bool> _handlePermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    if (allGranted) return true;

    if (statuses[Permission.bluetoothScan]!.isDenied ||
        statuses[Permission.bluetoothConnect]!.isDenied) {
      _showSnackBar('Los permisos de Bluetooth son necesarios.', isError: true);
    }

    if (statuses[Permission.bluetoothScan]!.isPermanentlyDenied ||
        statuses[Permission.bluetoothConnect]!.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }

// --- Función auxiliar robusta y limpia para detectar tus AI Chatbots ---
  bool _isAiChatbot(DiscoveredDevice device) {
    try {
      final Uint8List adv = device.manufacturerData;

      // 🔹 Verificar marker "AIC" o variantes extendidas ("AIC2", "AIC3", etc.)
      if (adv.isNotEmpty && _matchesMarker(adv)) {
        return true;
      }

      // 🔹 Fallback por nombre (por si Android tarda en anunciar manufacturerData)
      if (device.name.isNotEmpty && device.name.startsWith('AIChatbot-')) {
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error analizando manufacturerData: $e');
    }

    return false;
  }

// --- Subfunción para comparar los posibles marcadores ---
  bool _matchesMarker(Uint8List data) {
    // Validar prefijo "AIC"
    if (data.length >= 3 &&
        data[0] == 0x41 && // 'A'
        data[1] == 0x49 && // 'I'
        data[2] == 0x43) {
      // 'C'

      // Variante extendida (AIC2, AIC3, etc.)
      if (data.length >= 4) {
        final next = data[3];
        if (next >= 0x32 && next <= 0x39) {
          // '2'–'9'
          debugPrint(
              '🔍 Detectado marker extendido: AIC${String.fromCharCode(next)}');
        }
      }
      return true;
    }
    return false;
  }

// --- Función principal de escaneo BLE ---
  void scanForDevices() async {
    // Si ya está escaneando, detener el escaneo actual primero
    if (isScanning) {
      debugPrint(
          'Ya hay un escaneo en curso. Deteniéndolo para iniciar uno nuevo...');
      _stopScanning();
      await Future.delayed(const Duration(milliseconds: 300)); // Pequeña pausa
    }

    // Limpiar la lista SOLO al inicio de una nueva búsqueda
    discoveredDevices.clear();

    setState(() => isScanning = true);
    _animationController.repeat();

    // Verificar permisos
    if (!await _handlePermissions()) {
      _stopScanning();
      return;
    }

    // Verificar estado de Bluetooth
    if (!await _checkBluetoothStatus()) {
      _stopScanning();
      return;
    }

    // Limpiar conexión previa si existe
    await connectionSub?.cancel();
    selectedDevice = null;
    _wifiCredsChar = null;
    _apiKeyChar = null;
    _sysCmdChar = null;

    setState(() {});

    try {
      scanSub = flutterReactiveBle.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen(
        (device) {
          if (!mounted) return;

          // --- Aplicar filtrado inteligente ---
          final isMyDevice = _isAiChatbot(device);

          if (isMyDevice) {
            // Evitar duplicados
            if (!discoveredDevices.any((d) => d.id == device.id)) {
              setState(() => discoveredDevices.add(device));
              debugPrint(
                  '✅ Detectado AI Chatbot: ${device.name.isNotEmpty ? device.name : "Sin nombre"} (${device.id})');
            }
          } else {
            debugPrint(
                'Ignorando dispositivo no válido: ${device.name.isNotEmpty ? device.name : "Sin nombre"}');
          }
        },
        onError: (error) {
          debugPrint('❌ Error durante el escaneo: $error');
          if (mounted) {
            _showSnackBar('Error durante el escaneo: $error', isError: true);
          }
          _stopScanning();
        },
        onDone: () {
          debugPrint('✅ Escaneo completado');
          if (mounted) {
            _stopScanning();
          }
        },
      );

      // Timer para detener el escaneo después de 15 segundos
      Timer(const Duration(seconds: 10), () {
        if (isScanning) {
          debugPrint(
              '⏱️ Tiempo de escaneo agotado (10s). Deteniendo búsqueda...');
          scanSub?.cancel();

          if (mounted) {
            setState(() {
              isScanning = false;
              _animationController.stop();
              _animationController.reset();
            });

            if (discoveredDevices.isNotEmpty) {
              _showSnackBar(
                'Búsqueda completada. ${discoveredDevices.length} dispositivo(s) encontrado(s)',
                isError: false,
              );
            } else {
              _showSnackBar(
                'No se encontraron AI Chatbots. Intenta buscar nuevamente.',
                isError: false,
              );
            }
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error al iniciar escaneo: $e');
      if (mounted) {
        _showSnackBar('Error al iniciar escaneo: $e', isError: true);
      }
      _stopScanning();
    }
  }

  void _resetConnectionState() {
    debugPrint('🔄 Reseteando estado de conexión...');

    // Cancelar todas las suscripciones activas
    connectionSub?.cancel();
    scanSub?.cancel();

    // Resetear TODAS las variables de estado
    setState(() {
      selectedDevice = null;
      _wifiCredsChar = null;
      _apiKeyChar = null;
      _sysCmdChar = null;
      isConnecting = false;
      isScanning = false;
      isSendingWifi = false;
      isSendingApiKey = false;
      isSending = false;

      // Limpiar también la lista de dispositivos descubiertos
      discoveredDevices.clear();
    });

    // Detener animaciones
    _animationController.stop();
    _animationController.reset();

    debugPrint('✅ Estado reseteado completamente');
  }

  void connectToDevice(DiscoveredDevice device) async {
    if (isConnecting) return;
    if (!await _checkBluetoothStatus()) return;

    setState(() {
      isConnecting = true;
      selectedDevice = device;
    });

    discoveredDevices.clear();
    await scanSub?.cancel();
    reconnectAttempts = 0;
    _animationController.stop();
    _animationController.reset();
    setState(() => isScanning = false);

    try {
      connectionSub = flutterReactiveBle
          .connectToDevice(
        id: device.id,
        connectionTimeout: const Duration(seconds: 15),
      )
          .listen(
        (event) async {
          if (!mounted) return;

          if (event.connectionState == DeviceConnectionState.connected) {
            setState(() => isConnecting = false);

            try {
              debugPrint('🔍 Descubriendo servicios del dispositivo...');
              await flutterReactiveBle.discoverAllServices(device.id);
              final services =
                  await flutterReactiveBle.getDiscoveredServices(device.id);

              debugPrint(
                  '📋 Total de servicios encontrados: ${services.length}');

              // Imprimir TODOS los servicios y características para debugging
              for (var service in services) {
                debugPrint('📦 Servicio UUID: ${service.id}');
                for (var char in service.characteristics) {
                  debugPrint('  └─ Característica UUID: ${char.id}');
                }
              }

              // Resetear características antes de buscar
              _wifiCredsChar = null;
              _apiKeyChar = null;
              _sysCmdChar = null;

              // Buscar características en TODOS los servicios (más robusto)
              bool foundAny = false;

              for (var service in services) {
                for (var char in service.characteristics) {
                  final uuid = char.id.toString().toLowerCase();

                  // Buscar característica de WiFi
                  if (uuid == '01ffbc9a-7856-3412-ffde-bc9a78563412') {
                    _wifiCredsChar = QualifiedCharacteristic(
                      characteristicId: char.id,
                      serviceId: service.id,
                      deviceId: device.id,
                    );
                    debugPrint('✅ Característica de WiFi encontrada');
                    foundAny = true;
                  }
                  // Buscar característica de API Key
                  else if (uuid == '02ffbc9a-7856-3412-ffde-bc9a78563412') {
                    _apiKeyChar = QualifiedCharacteristic(
                      characteristicId: char.id,
                      serviceId: service.id,
                      deviceId: device.id,
                    );
                    debugPrint('✅ Característica de API Key encontrada');
                    foundAny = true;
                  }
                  // Buscar característica de Comandos del Sistema
                  else if (uuid == '03ffbc9a-7856-3412-ffde-bc9a78563412') {
                    _sysCmdChar = QualifiedCharacteristic(
                      characteristicId: char.id,
                      serviceId: service.id,
                      deviceId: device.id,
                    );
                    debugPrint('✅ Característica de Comandos encontrada');
                    foundAny = true;
                  }
                }
              }

              if (!mounted) return;

              if (foundAny) {
                // Mostrar qué características se encontraron
                List<String> found = [];
                if (_wifiCredsChar != null) found.add('WiFi');
                if (_apiKeyChar != null) found.add('API Key');
                if (_sysCmdChar != null) found.add('Comandos');

                debugPrint(
                    '🎉 Características disponibles: ${found.join(", ")}');

                setState(() {});
                _showSnackBar(
                  'Dispositivo conectado. Disponible: ${found.join(", ")}',
                  isError: false,
                );
              } else {
                debugPrint('❌ No se encontró ninguna característica conocida');
                _showSnackBar(
                  'No se encontraron características. Verifica el firmware.',
                  isError: true,
                );
                _resetConnectionState();
              }
            } catch (e) {
              debugPrint('❌ Error discovering services: $e');
              if (!mounted) return;
              _showSnackBar('Error al descubrir servicios: $e', isError: true);
              _resetConnectionState();
            }
          } else if (event.connectionState ==
              DeviceConnectionState.disconnected) {
            if (selectedDevice != null &&
                reconnectAttempts < maxReconnectAttempts) {
              reconnectAttempts++;
              connectionSub?.cancel();
              connectionSub = null;
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) connectToDevice(device);
            } else {
              if (mounted) {
                _showSnackBar('No se pudo reconectar', isError: true);
              }
              _resetConnectionState();
            }
          }
        },
        onError: (error) {
          if (!mounted) return;
          _resetConnectionState();
          _showSnackBar('Error de conexión: $error', isError: true);
        },
      );
    } catch (e) {
      if (!mounted) return;
      _resetConnectionState();
      _showSnackBar('Error al iniciar conexión: $e', isError: true);
    }
  }

  void sendWifiCommand() async {
    if (!isWifiFormValid) {
      _showSnackBar('Completa todos los campos WiFi correctamente.',
          isError: true);
      return;
    }
    if (!await _checkBluetoothStatus()) return;

    setState(() => isSendingWifi = true);

    try {
      try {
        final negotiatedMtu = await flutterReactiveBle.requestMtu(
          deviceId: _wifiCredsChar!.deviceId,
          mtu: 247,
        );
        debugPrint('📡 MTU negociado: $negotiatedMtu bytes');
      } catch (e) {
        debugPrint('⚠️ No se pudo negociar MTU: $e');
      }

      final ssid = ssidController.text.trim();
      final password = passwordController.text.trim();
      final cmd = '$ssid $password';

      debugPrint('📤 Enviando credenciales WiFi:');
      debugPrint('   SSID: $ssid (${ssid.length} caracteres)');
      debugPrint('   Password: [${password.length} caracteres]');

      await flutterReactiveBle.writeCharacteristicWithResponse(
        _wifiCredsChar!,
        value: utf8.encode(cmd),
      );

      debugPrint('✅ Credenciales enviadas correctamente');

      if (mounted) {
        // ⬇️ IMPORTANTE: Primero resetear el estado de envío
        setState(() => isSendingWifi = false);

        _showSnackBar(
          '✅ Credenciales enviadas. El dispositivo se reiniciará...',
          isError: false,
        );

        // ⬇️ CRÍTICO: Resetear INMEDIATAMENTE (no esperar)
        _resetConnectionState();

        // Esperar solo para el segundo mensaje
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _showSnackBar('Puedes buscar dispositivos nuevamente.', isError: false);
        });
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout esperado - El dispositivo se reinició');

      if (mounted) {
        setState(() => isSendingWifi = false);

        _showSnackBar(
          '✅ Credenciales enviadas. El dispositivo se está reiniciando...',
          isError: false,
        );

        // ⬇️ Resetear inmediatamente
        _resetConnectionState();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _showSnackBar('Puedes buscar dispositivos nuevamente.', isError: false);
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');

      if (mounted) {
        setState(() => isSendingWifi = false);

        if (!e.toString().contains('disconnected') &&
            !e.toString().contains('connection') &&
            !e.toString().contains('GATT')) {
          _showSnackBar('Error al enviar credenciales: $e', isError: true);
        } else {
          _showSnackBar(
            '✅ Credenciales enviadas. Dispositivo reiniciado.',
            isError: false,
          );

          // ⬇️ Resetear inmediatamente
          _resetConnectionState();

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _showSnackBar('Puedes buscar dispositivos nuevamente.', isError: false);
          });
        }
      }
    }
  }


  void sendApiKeyCommand() async {
    if (!isApiKeyFormValid) {
      _showSnackBar('Ingresa una API Key válida.', isError: true);
      return;
    }
    if (!await _checkBluetoothStatus()) return;

    setState(() => isSendingApiKey = true);

    try {
      final apiKey = apiKeyController.text.trim();

      debugPrint('📤 Enviando API Key (${apiKey.length} caracteres)');

      await flutterReactiveBle.writeCharacteristicWithoutResponse(
        _apiKeyChar!,
        value: utf8.encode(apiKey),
      );

      debugPrint('✅ API Key enviada correctamente');

      if (mounted) {
        setState(() => isSendingApiKey = false);

        _showSnackBar(
          '✅ API Key enviada. El dispositivo se reiniciará...',
          isError: false,
        );

        // ⬇️ Resetear inmediatamente
        _resetConnectionState();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _showSnackBar('Puedes buscar dispositivos nuevamente.', isError: false);
        });
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout esperado - El dispositivo se reinició');

      if (mounted) {
        setState(() => isSendingApiKey = false);
        _showSnackBar(
          '✅ API Key enviada. Dispositivo reiniciándose...',
          isError: false,
        );

        _resetConnectionState();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _showSnackBar('Puedes buscar dispositivos nuevamente.', isError: false);
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');

      if (mounted) {
        setState(() => isSendingApiKey = false);

        if (!e.toString().contains('disconnected') &&
            !e.toString().contains('connection')) {
          _showSnackBar('Error al enviar API Key: $e', isError: true);
        } else {
          _showSnackBar(
            '✅ API Key enviada. Dispositivo reiniciado.',
            isError: false,
          );

          _resetConnectionState();

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _showSnackBar('Puedes buscar dispositivos nuevamente.', isError: false);
          });
        }
      }
    }
  }
  void sendEraseNvsCommand() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar borrado'),
        content: const Text('¿Estás seguro de borrar todas las credenciales?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_sysCmdChar == null) {
      _showSnackBar('Característica de comandos no encontrada.', isError: true);
      return;
    }

    if (!await _checkBluetoothStatus()) return;

    setState(() => isSending = true);

    try {
      await flutterReactiveBle.writeCharacteristicWithoutResponse(
        _sysCmdChar!,
        value: utf8.encode('CMD:ERASE_NVS'),
      );

      debugPrint('✅ Comando de borrado enviado');

      if (mounted) {
        setState(() => isSending = false);

        _showSnackBar(
          '✅ NVS borrada. El dispositivo se reiniciará...',
          isError: false,
        );

        // ⬇️ Resetear inmediatamente
        _resetConnectionState();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _showSnackBar('Puedes configurar el dispositivo nuevamente.', isError: false);
        });
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout esperado - El dispositivo se reinició');

      if (mounted) {
        setState(() => isSending = false);
        _showSnackBar(
          '✅ NVS borrada. Dispositivo reiniciándose...',
          isError: false,
        );

        _resetConnectionState();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _showSnackBar('Puedes configurar el dispositivo nuevamente.', isError: false);
        });
      }
    } catch (e) {
      debugPrint('Error: $e');

      if (mounted) {
        setState(() => isSending = false);

        if (!e.toString().contains('disconnected') &&
            !e.toString().contains('connection')) {
          _showSnackBar('Error al enviar comando: $e', isError: true);
        } else {
          _showSnackBar(
            '✅ NVS borrada. Dispositivo reiniciado.',
            isError: false,
          );

          _resetConnectionState();

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _showSnackBar('Puedes configurar el dispositivo nuevamente.', isError: false);
          });
        }
      }
    }
  }

  // void sendEraseNvsCommand() async {
  //   if (!mounted) return;

  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       backgroundColor: const Color(0xFF1A1A1A),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Text('Confirmar borrado'),
  //       content: const Text('¿Estás seguro de borrar todas las credenciales?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx, false),
  //           child: const Text('Cancelar'),
  //         ),
  //         ElevatedButton(
  //           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  //           onPressed: () => Navigator.pop(ctx, true),
  //           child: const Text('Borrar'),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirmed != true) return;

  //   if (_sysCmdChar == null) {
  //     _showSnackBar('Característica de comandos no encontrada.', isError: true);
  //     return;
  //   }

  //   if (!await _checkBluetoothStatus()) return;

  //   setState(() => isSending = true);

  //   try {
  //     await flutterReactiveBle.writeCharacteristicWithoutResponse(
  //       _sysCmdChar!,
  //       value: utf8.encode('CMD:ERASE_NVS'),
  //     );
  //     if (mounted) {
  //       _showSnackBar('Comando enviado. El dispositivo se reiniciará.',
  //           isError: false);

  //       // --- INICIO DE LA CORRECCIÓN ---
  //       // Hacemos lo mismo aquí.
  //       Future.delayed(const Duration(milliseconds: 1500), () {
  //         if (mounted) {
  //           _resetConnectionState();
  //           scanForDevices();
  //         }
  //       });
  //       // --- FIN DE LA CORRECCIÓN ---
  //     }
  //   } catch (e) {
  //     if (mounted) _showSnackBar('Error al enviar comando: $e', isError: true);
  //   } finally {
  //     if (mounted) setState(() => isSending = false);
  //   }
  // }

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
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Future<void> closeApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Confirmar salida'),
          ],
        ),
        content: const Text('¿Estás seguro que deseas cerrar la aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _cleanupResources();
      SystemNavigator.pop();
    }
  }

  void _cleanupResources() {
    connectionSub?.cancel();
    scanSub?.cancel();
    bleStatusSub?.cancel();
    _animationController.dispose();
  }

  @override
  void dispose() {
    ssidController.dispose();
    passwordController.dispose();
    apiKeyController.dispose(); // NUEVO
    _cleanupResources();
    super.dispose();
  }

  // UI WIDGETS

  Widget _buildDeviceStatusCard() {
    final isConnected = selectedDevice != null;
    return Card(
      elevation: 12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isConnected
                ? [Colors.green.shade800, Colors.green.shade600]
                : [Colors.red.shade800, Colors.red.shade600],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isConnected ? 'CONECTADO' : 'DESCONECTADO',
                            style: TextStyle(
                              color: isConnected
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isConnected
                              ? 'Dispositivo Conectado'
                              : 'Sin Dispositivo',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isConnected) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedDevice!.name.isNotEmpty
                            ? selectedDevice!.name
                            : 'Dispositivo sin nombre',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        selectedDevice!.id,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 12),
                      _buildCharacteristicStatus(
                          'WiFi', _wifiCredsChar != null),
                      _buildCharacteristicStatus(
                          'API Key', _apiKeyChar != null),
                      _buildCharacteristicStatus(
                          'Comandos', _sysCmdChar != null),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacteristicStatus(String name, bool found) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            found ? Icons.check_circle : Icons.cancel,
            color: found ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$name: ${found ? "Disponible" : "No disponible"}',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    if (selectedDevice != null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.radar,
                    color: Color(0xFF1976D2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Buscar Dispositivos ESP32-S3',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ NUEVO: Mostrar estado actual
            if (discoveredDevices.isNotEmpty && !isScanning) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${discoveredDevices.length} dispositivo(s) encontrado(s). Presiona buscar para actualizar.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              isScanning
                  ? 'Escaneando dispositivos ESP32-S3 cercanos...'
                  : 'Escanea dispositivos ESP32-S3 cercanos para encontrar tu AI Chatbot.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isScanning ? null : scanForDevices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isScanning
                      ? Colors.grey.shade700
                      : const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: isScanning
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _animation.value * 2 * 3.14159,
                              child: const Icon(Icons.refresh, size: 24),
                            );
                          },
                        ),
                      )
                    : Icon(
                        discoveredDevices.isEmpty
                            ? Icons.bluetooth_searching
                            : Icons
                                .refresh, // Cambiar icono si ya hay dispositivos
                        size: 24,
                      ),
                label: Text(
                  isScanning
                      ? 'Escaneando dispositivos...'
                      : discoveredDevices.isEmpty
                          ? 'Iniciar Búsqueda'
                          : 'Buscar Nuevamente', // Texto diferente si ya hay dispositivos
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceListCard() {
    if (selectedDevice != null || discoveredDevices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.devices,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Dispositivos Encontrados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${discoveredDevices.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Toca un dispositivo para conectarte',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            ...discoveredDevices.map((device) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade800,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bluetooth,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      device.name.isNotEmpty
                          ? device.name
                          : 'Dispositivo sin nombre',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          device.id,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.signal_cellular_4_bar,
                              size: 14,
                              color: _getSignalColor(device.rssi),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${device.rssi} dBm',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getSignalColor(device.rssi),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: isConnecting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.touch_app,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                    onTap: isConnecting ? null : () => connectToDevice(device),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi > -50) return Colors.green;
    if (rssi > -70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildWifiConfigCard() {
    if (selectedDevice == null || _wifiCredsChar == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wifi, color: Colors.green),
                SizedBox(width: 12),
                Text('Configuración WiFi',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ssidController,
              decoration: const InputDecoration(
                labelText: 'SSID WiFi',
                hintText: 'Nombre de tu red',
                prefixIcon: Icon(Icons.router),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña WiFi',
                hintText: 'Mínimo 4 caracteres',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                      showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => showPassword = !showPassword),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (isWifiFormValid && !isSendingWifi)
                    ? sendWifiCommand
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isWifiFormValid
                      ? Colors.green.shade600
                      : Colors.grey.shade700,
                ),
                icon: isSendingWifi
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(isSendingWifi
                    ? 'Enviando WiFi...'
                    : 'Enviar Credenciales WiFi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NUEVA CARD: API Key Configuration
  Widget _buildApiKeyConfigCard() {
    if (selectedDevice == null || _apiKeyChar == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.vpn_key, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Configuración API Key',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Ingresa tu API Key para habilitar funciones del chatbot',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: apiKeyController,
              obscureText: !showApiKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'Ej: sk-proj-xxxxxxxxxxxxx',
                prefixIcon: const Icon(Icons.key, color: Colors.grey),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (apiKeyController.text.isNotEmpty)
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                    IconButton(
                      icon: Icon(
                          showApiKey ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey),
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
                onPressed: (isApiKeyFormValid && !isSendingApiKey)
                    ? sendApiKeyCommand
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApiKeyFormValid
                      ? Colors.purple.shade600
                      : Colors.grey.shade700,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: isSendingApiKey
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 24),
                label: Text(
                  isSendingApiKey ? 'Enviando API Key...' : 'Enviar API Key',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (!isApiKeyFormValid && selectedDevice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _apiKeyChar == null
                            ? 'La característica de API Key no está disponible en este dispositivo'
                            : apiKeyController.text.isEmpty
                                ? 'Ingresa una API Key válida para continuar'
                                : 'La API Key no es válida',
                        style:
                            const TextStyle(color: Colors.orange, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptionsCard() {
    if (selectedDevice == null || _sysCmdChar == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Opciones Avanzadas',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.dangerous, color: Colors.red, size: 28),
                    SizedBox(height: 8),
                    Text(
                      '⚠️ PRECAUCIÓN',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Esta operación borrará permanentemente todas las credenciales WiFi y API Keys almacenadas.',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever, size: 24),
                  label: Text(
                    isSending ? 'Borrando...' : 'Borrar Todas las Credenciales',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: isSending ? null : sendEraseNvsCommand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'AI ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                  // Ícono Bluetooth con glow
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.9),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.bluetooth,
                        size: 30,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                  // Pegamos la "r" encima del ícono
                  Transform.translate(
                    offset: const Offset(
                        -6, 0), // mueve "ridge" 6px hacia la izquierda
                    child: const Text(
                      'ridge',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E3C72), // azul medio
                      Color(0xFF2A5298), // violeta
                      Color(0xFF6C63FF), // acento violeta-azul brillante
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar aplicación',
                onPressed: closeApp,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // PASO 1: Estado del Dispositivo
                _buildDeviceStatusCard(),
                const SizedBox(height: 16),

                // PASO 2: Buscar Dispositivos
                _buildSearchCard(),
                if (selectedDevice == null) const SizedBox(height: 16),

                // PASO 3: Lista de Dispositivos
                _buildDeviceListCard(),
                if (discoveredDevices.isNotEmpty && selectedDevice == null)
                  const SizedBox(height: 16),

                // PASO 4: Configuración WiFi
                _buildWifiConfigCard(),
                if (selectedDevice != null && _wifiCredsChar != null)
                  const SizedBox(height: 16),

                // PASO 5: Configuración API Key (NUEVA)
                _buildApiKeyConfigCard(),
                if (selectedDevice != null && _apiKeyChar != null)
                  const SizedBox(height: 16),

                // PASO 6: Opciones Avanzadas
                _buildAdvancedOptionsCard(),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
