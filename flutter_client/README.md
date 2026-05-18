# GPS Control EC — APK Cliente

## Antes de compilar

### 1. Configurar la URL del backend
Edita `lib/config.dart`:

```dart
// Para probar en emulador Android (apunta a tu localhost):
const String kApiBase = 'http://10.0.2.2:8000';

// Para probar en teléfono físico (usa tu IP local):
// const String kApiBase = 'http://192.168.1.XX:8000';

// Para producción:
// const String kApiBase = 'https://tu-backend.onrender.com';
```

### 2. Configurar contraseña GPS
En `lib/config.dart`:
```dart
const String kGpsPassword = '123456';  // la contraseña de tu GPS físico
```

---

## Compilar

```bash
flutter pub get
flutter build apk --release
```

APK generada en: `build/app/outputs/flutter-apk/app-release.apk`

---

## Comandos SMS implementados

| Botón | SMS enviado |
|-------|------------|
| Localizar | `check123456` |
| Apagar motor | `stop123456` |
| Encender motor | `resume123456` |
| Alerta movimiento | `move123456` |
| Alerta velocidad | `speed123456 080` |
| Modo activo | `online123456` |
| Micrófono | `monitor123456` |

---

## Notas

- **Emulador**: usa `10.0.2.2` para acceder al localhost de tu PC
- **Teléfono físico**: usa la IP de tu PC en la red WiFi (ej: `192.168.1.10`)
- El número SIM viene del backend al hacer login — el cliente nunca lo ve
- Los SMS se envían directo desde el teléfono del cliente al GPS
