import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/ble_constants.dart';

enum BleOperationStatus { idle, sending, success, error, timeout }

class BleMessage {
  final String text;
  final bool isError;
  BleMessage(this.text, {this.isError = false});
}

class BleService extends ChangeNotifier {
  final flutterReactiveBle = FlutterReactiveBle();

  // State Variables
  final List<DiscoveredDevice> _discoveredDevices = [];
  DiscoveredDevice? _selectedDevice;
  
  QualifiedCharacteristic? _wifiCredsChar;
  QualifiedCharacteristic? _apiKeyChar;
  QualifiedCharacteristic? _sysCmdChar;

  bool _isScanning = false;
  bool _isConnecting = false;
  BleOperationStatus _operationStatus = BleOperationStatus.idle;

  // Subscriptions
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  StreamSubscription<BleStatus>? _bleStatusSub;

  int _reconnectAttempts = 0;
  final int maxReconnectAttempts = 3;

  // Callbacks for UI
  void Function(BleMessage)? onMessage;
  void Function()? onBluetoothDisabled;
  void Function()? onBluetoothOff;

  // Getters
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;
  DiscoveredDevice? get selectedDevice => _selectedDevice;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isSending => _operationStatus == BleOperationStatus.sending;
  QualifiedCharacteristic? get wifiCredsChar => _wifiCredsChar;
  QualifiedCharacteristic? get apiKeyChar => _apiKeyChar;
  QualifiedCharacteristic? get sysCmdChar => _sysCmdChar;

  BleService() {
    _initializeBleStatusListener();
  }

  void _initializeBleStatusListener() {
    _bleStatusSub = flutterReactiveBle.statusStream.listen((status) {
      debugPrint('BLE Status changed: $status');
      if (status != BleStatus.ready && (_isScanning || _selectedDevice != null)) {
        if (_isScanning) stopScan();
        if (_selectedDevice != null) disconnect();
        onBluetoothDisabled?.call();
      }
    });
  }

  void stopScan() {
    _isScanning = false;
    _scanSub?.cancel();
    _discoveredDevices.clear();
    notifyListeners();
  }

  void disconnect() {
    _connectionSub?.cancel();
    _selectedDevice = null;
    _wifiCredsChar = null;
    _apiKeyChar = null;
    _sysCmdChar = null;
    _isConnecting = false;
    notifyListeners();
  }

  Future<bool> _requestBluetoothPermissions() async {
    try {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      return (statuses[Permission.bluetooth]?.isGranted ?? false) ||
          (statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
          (statuses[Permission.bluetoothConnect]?.isGranted ?? false) ||
          (statuses[Permission.locationWhenInUse]?.isGranted ?? false);
    } catch (e) {
      debugPrint('[PERM] Error pidiendo permisos: $e');
      return false;
    }
  }

  Future<bool> _checkBluetoothStatus() async {
    BleStatus status;
    try {
      status = await flutterReactiveBle.statusStream.first;
    } catch (e) {
      status = BleStatus.unknown;
    }

    switch (status) {
      case BleStatus.ready:
        return true;
      case BleStatus.poweredOff:
        onBluetoothOff?.call();
        return false;
      case BleStatus.unsupported:
        _sendMessage('Bluetooth no soportado en este dispositivo.', isError: true);
        return false;
      case BleStatus.locationServicesDisabled:
        _sendMessage('Los servicios de ubicación están desactivados.', isError: true);
        return false;
      case BleStatus.unauthorized:
      case BleStatus.unknown:
        bool permsGranted = await _requestBluetoothPermissions();
        if (!permsGranted) {
          _sendMessage('Permisos Bluetooth no concedidos.', isError: true);
          return false;
        }
        try {
          final nextStatus = await flutterReactiveBle.statusStream
              .firstWhere((s) => s != status)
              .timeout(const Duration(seconds: 3));
          
          if (nextStatus == BleStatus.ready) return true;
          if (nextStatus == BleStatus.poweredOff) {
            onBluetoothOff?.call();
            return false;
          }
          _sendMessage('Estado de Bluetooth no válido: $nextStatus', isError: true);
          return false;
        } catch (e) {
          _sendMessage('Esperando permisos/estado de Bluetooth. Intenta nuevamente.', isError: false);
          return false;
        }
    }
  }

  bool _isAiChatbot(DiscoveredDevice device) {
    try {
      final Uint8List adv = device.manufacturerData;
      if (adv.isNotEmpty && adv.length >= 3) {
        if (adv[0] == BleConstants.aiMarkerPrefix[0] &&
            adv[1] == BleConstants.aiMarkerPrefix[1] &&
            adv[2] == BleConstants.aiMarkerPrefix[2]) {
          return true;
        }
      }
      if (device.name.isNotEmpty && device.name.startsWith('AIChatbot-')) {
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error analizando manufacturerData: $e');
    }
    return false;
  }

  Future<void> scanForDevices() async {
    if (_isScanning) {
      stopScan();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _discoveredDevices.clear();
    _isScanning = true;
    notifyListeners();

    if (!await _checkBluetoothStatus()) {
      stopScan();
      return;
    }

    disconnect();

    try {
      _scanSub = flutterReactiveBle.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen(
        (device) {
          if (_isAiChatbot(device)) {
            if (!_discoveredDevices.any((d) => d.id == device.id)) {
              _discoveredDevices.add(device);
              notifyListeners();
            }
          }
        },
        onError: (error) {
          _sendMessage('Error durante el escaneo: $error', isError: true);
          stopScan();
        },
        onDone: () => stopScan(),
      );

      Timer(const Duration(seconds: 10), () {
        if (_isScanning) {
          stopScan();
          if (_discoveredDevices.isNotEmpty) {
            _sendMessage('Búsqueda completada. ${_discoveredDevices.length} dispositivo(s) encontrado(s)', isError: false);
          } else {
            _sendMessage('No se encontraron AI Chatbots. Intenta buscar nuevamente.', isError: false);
          }
        }
      });
    } catch (e) {
      _sendMessage('Error al iniciar escaneo: $e', isError: true);
      stopScan();
    }
  }

  void resetConnectionState() {
    _connectionSub?.cancel();
    _scanSub?.cancel();
    _selectedDevice = null;
    _wifiCredsChar = null;
    _apiKeyChar = null;
    _sysCmdChar = null;
    _isConnecting = false;
    _isScanning = false;
    _operationStatus = BleOperationStatus.idle;
    _discoveredDevices.clear();
    notifyListeners();
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    if (_isConnecting) return;
    if (!await _checkBluetoothStatus()) return;

    _isConnecting = true;
    _selectedDevice = device;
    notifyListeners();

    _discoveredDevices.clear();
    await _scanSub?.cancel();
    _reconnectAttempts = 0;
    _isScanning = false;
    notifyListeners();

    try {
      _connectionSub = flutterReactiveBle
          .connectToDevice(
        id: device.id,
        connectionTimeout: const Duration(seconds: 15),
      )
          .listen(
        (event) async {
          if (event.connectionState == DeviceConnectionState.connected) {
            _isConnecting = false;
            notifyListeners();

            try {
              await flutterReactiveBle.discoverAllServices(device.id);
              final services = await flutterReactiveBle.getDiscoveredServices(device.id);

              _wifiCredsChar = null;
              _apiKeyChar = null;
              _sysCmdChar = null;

              bool foundAny = false;

              for (var service in services) {
                for (var char in service.characteristics) {
                  final uuid = char.id.toString().toLowerCase();

                  if (uuid == BleConstants.wifiCredsCharacteristicUuid) {
                    _wifiCredsChar = QualifiedCharacteristic(
                      characteristicId: char.id,
                      serviceId: service.id,
                      deviceId: device.id,
                    );
                    foundAny = true;
                  } else if (uuid == BleConstants.apiKeyCharacteristicUuid) {
                    _apiKeyChar = QualifiedCharacteristic(
                      characteristicId: char.id,
                      serviceId: service.id,
                      deviceId: device.id,
                    );
                    foundAny = true;
                  } else if (uuid == BleConstants.sysCmdCharacteristicUuid) {
                    _sysCmdChar = QualifiedCharacteristic(
                      characteristicId: char.id,
                      serviceId: service.id,
                      deviceId: device.id,
                    );
                    foundAny = true;
                  }
                }
              }

              if (foundAny) {
                List<String> found = [];
                if (_wifiCredsChar != null) found.add('WiFi');
                if (_apiKeyChar != null) found.add('API Key');
                if (_sysCmdChar != null) found.add('Comandos');

                notifyListeners();
                _sendMessage('Dispositivo conectado. Disponible: ${found.join(", ")}', isError: false);
              } else {
                _sendMessage('No se encontraron características. Verifica el firmware.', isError: true);
                resetConnectionState();
              }
            } catch (e) {
              _sendMessage('Error al descubrir servicios: $e', isError: true);
              resetConnectionState();
            }
          } else if (event.connectionState == DeviceConnectionState.disconnected) {
            if (_selectedDevice != null && _reconnectAttempts < maxReconnectAttempts) {
              _reconnectAttempts++;
              _connectionSub?.cancel();
              _connectionSub = null;
              await Future.delayed(const Duration(seconds: 2));
              connectToDevice(device);
            } else {
              _sendMessage('No se pudo reconectar', isError: true);
              resetConnectionState();
            }
          }
        },
        onError: (error) {
          resetConnectionState();
          _sendMessage('Error de conexión: $error', isError: true);
        },
      );
    } catch (e) {
      resetConnectionState();
      _sendMessage('Error al iniciar conexión: $e', isError: true);
    }
  }

  Future<void> executeCommand({
    required QualifiedCharacteristic characteristic,
    required String payload,
    required String successMessage,
    bool withResponse = true,
  }) async {
    if (!await _checkBluetoothStatus()) return;

    _operationStatus = BleOperationStatus.sending;
    notifyListeners();

    try {
      try {
        await flutterReactiveBle.requestMtu(
          deviceId: characteristic.deviceId,
          mtu: 247,
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo negociar MTU: $e');
      }

      if (withResponse) {
        await flutterReactiveBle.writeCharacteristicWithResponse(
          characteristic,
          value: utf8.encode(payload),
        );
      } else {
        await flutterReactiveBle.writeCharacteristicWithoutResponse(
          characteristic,
          value: utf8.encode(payload),
        );
      }

      _operationStatus = BleOperationStatus.idle;
      _sendMessage(successMessage, isError: false);
      resetConnectionState();

      Future.delayed(const Duration(seconds: 2), () {
        _sendMessage('Puedes buscar dispositivos nuevamente.', isError: false);
      });
    } on TimeoutException {
      _operationStatus = BleOperationStatus.idle;
      _sendMessage('$successMessage (Reinicio en proceso...)', isError: false);
      resetConnectionState();

      Future.delayed(const Duration(seconds: 2), () {
        _sendMessage('Puedes buscar dispositivos nuevamente.', isError: false);
      });
    } catch (e) {
      _operationStatus = BleOperationStatus.idle;
      if (!e.toString().contains('disconnected') && !e.toString().contains('connection')) {
        _sendMessage('Error al enviar comando: $e', isError: true);
      } else {
        _sendMessage('$successMessage (Dispositivo reiniciado)', isError: false);
        resetConnectionState();

        Future.delayed(const Duration(seconds: 2), () {
          _sendMessage('Puedes buscar dispositivos nuevamente.', isError: false);
        });
      }
    }
  }

  void _sendMessage(String message, {bool isError = false}) {
    onMessage?.call(BleMessage(message, isError: isError));
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _scanSub?.cancel();
    _bleStatusSub?.cancel();
    super.dispose();
  }
}
