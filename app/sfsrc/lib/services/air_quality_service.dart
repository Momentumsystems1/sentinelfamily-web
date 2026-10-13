import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Lectura de calidad del aire (AQI europeo) de Open-Meteo.
/// Fuente: CAMS (Copernicus) — gratuita, sin clave, CORS abierto.
class AirQualityReading {
  final double lat;
  final double lng;
  final int aqi;
  final double? pm10;
  final double? pm25;
  final double? o3;
  final double? no2;

  const AirQualityReading({
    required this.lat,
    required this.lng,
    required this.aqi,
    this.pm10,
    this.pm25,
    this.o3,
    this.no2,
  });

  /// Etiqueta del nivel según AQI europeo (0–100+).
  String get levelLabel {
    if (aqi <= 20) return 'Buena';
    if (aqi <= 40) return 'Razonablemente buena';
    if (aqi <= 60) return 'Moderada';
    if (aqi <= 80) return 'Desfavorable';
    if (aqi <= 100) return 'Muy desfavorable';
    return 'Peligrosa';
  }

  /// Color del nivel.
  Color get levelColor {
    if (aqi <= 20) return const Color(0xFF4CAF50);
    if (aqi <= 40) return const Color(0xFF9CCC65);
    if (aqi <= 60) return const Color(0xFFFFC107);
    if (aqi <= 80) return const Color(0xFFFF9800);
    if (aqi <= 100) return const Color(0xFFF44336);
    return const Color(0xFF9C27B0);
  }

  /// Recomendación corta cuando el aire es malo.
  String? get advice {
    if (aqi <= 60) return null;
    if (aqi <= 80) {
      return 'Personas sensibles: reducir esfuerzo prolongado al aire libre.';
    }
    return 'Evitar actividad intensa al aire libre; posible irritación respiratoria.';
  }
}

class AirQualityService {
  static const String _base =
      'https://air-quality-api.open-meteo.com/v1/air-quality';
  static final Dio _dio = Dio();

  /// Consulta en lote (Open-Meteo acepta latitudes/longitudes separadas por comas).
  /// [points] = lista de [lat, lng]. Devuelve una lectura por punto en el mismo orden.
  static Future<List<AirQualityReading>> fetchBatch(
    List<List<double>> points,
  ) async {
    if (points.isEmpty) return [];
    final lats = points.map((p) => p[0].toStringAsFixed(5)).join(',');
    final lngs = points.map((p) => p[1].toStringAsFixed(5)).join(',');
    final uri =
        '$_base?latitude=$lats&longitude=$lngs&current=european_aqi,pm10,pm2_5,ozone,nitrogen_dioxide&timezone=auto';
    final res = await _dio.get<Map<String, dynamic>>(
      uri,
      options: Options(receiveTimeout: const Duration(seconds: 12)),
    );
    final data = res.data;
    if (data == null) return [];

    final current = data['current'];
    final List<Map<String, dynamic>> entries;
    if (current is List) {
      entries = current.cast<Map<String, dynamic>>();
    } else if (current is Map<String, dynamic>) {
      entries = [current];
    } else {
      return [];
    }

    final out = <AirQualityReading>[];
    for (var i = 0; i < entries.length && i < points.length; i++) {
      final e = entries[i];
      final aqi = (e['european_aqi'] as num?)?.toInt();
      if (aqi == null) continue;
      out.add(
        AirQualityReading(
          lat: points[i][0],
          lng: points[i][1],
          aqi: aqi,
          pm10: (e['pm10'] as num?)?.toDouble(),
          pm25: (e['pm2_5'] as num?)?.toDouble(),
          o3: (e['ozone'] as num?)?.toDouble(),
          no2: (e['nitrogen_dioxide'] as num?)?.toDouble(),
        ),
      );
    }
    return out;
  }
}
