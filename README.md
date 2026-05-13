# 🚀 AIBridge: BLE Bot Provisioning Engine

AIBridge is a high-performance Flutter application designed for the seamless configuration and provisioning of AI Chatbot hardware via Bluetooth Low Energy (BLE). It provides a robust interface for bridging the gap between local network connectivity and cloud intelligence.

## ✨ Key Features

- **🎯 Smart Scanning**: Advanced BLE filtering optimized for AI Chatbot identification using manufacturer data markers (`AIC`).
- **🔐 Secure Provisioning**: Encrypted-ready transmission of WiFi credentials (SSID/Password) to hardware nodes.
- **🔑 API Key Management**: Dedicated interface for injecting LLM/Cloud provider API keys into edge devices.
- **🛠️ System Orchestration**: Direct command interface for remote system restarts and hardware maintenance.
- **📱 Premium UX**: Modern, high-density dark interface with real-time connection state animations.

## 🛠️ Technology Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **Communication**: [flutter_reactive_ble](https://pub.dev/packages/flutter_reactive_ble) for high-reliability BLE streams.
- **Permissions**: Granular management via `permission_handler`.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (v3.6.0+)
- Bluetooth-enabled mobile device (Android/iOS)
- AI Chatbot Hardware (Firmware compatible with AIBridge BLE Service UUIDs)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

## 📐 Architecture Overview

AIBridge follows a reactive stream-based architecture:
- **Scanner**: Listens to BLE broadcast streams, decoding manufacturer data to identify valid hardware.
- **Connector**: Manages the lifecycle of the GATT connection with auto-reconnect logic.
- **Writer**: Handles MTU negotiation and character-encoding for reliable data transmission.

---

*Built with ❤️ for the AI Chatbot Ecosystem.*
