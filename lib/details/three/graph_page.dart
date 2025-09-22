import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class GraphPage extends StatefulWidget {
  final String uid;

  const GraphPage({super.key, required this.uid});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  List<FlSpot> _graphPoints = [];
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTemperatureData();
  }

  Future<void> _fetchTemperatureData() async {
    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('temperatureEntries');

      if (_fromDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: _fromDate);
      }
      if (_toDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: _toDate);
      }

      query = query.orderBy('timestamp');

      final snapshot = await query.get();

      final rawData = snapshot.docs.map((doc) {
        final temp = double.tryParse(doc['temperature'].toString()) ?? 0.0;
        final rawTimestamp = doc['timestamp'];
        final timestamp = rawTimestamp is Timestamp
            ? rawTimestamp.toDate()
            : DateTime.tryParse(rawTimestamp.toString()) ?? DateTime.now();

        return {'temperature': temp, 'timestamp': timestamp};
      }).toList();

      List<FlSpot> points = [];

      for (int i = 0; i < rawData.length; i++) {
        final ts = rawData[i]['timestamp'] as DateTime;
        final temp = rawData[i]['temperature'] as double;

        points.add(FlSpot(ts.millisecondsSinceEpoch.toDouble(), temp));

        // Handle gaps >30 minutes
        if (i < rawData.length - 1) {
          final nextTs = rawData[i + 1]['timestamp'] as DateTime;
          if (nextTs.difference(ts).inMinutes > 30) {
            final midTs = ts.add(nextTs.difference(ts) ~/ 2);
            points.add(FlSpot(midTs.millisecondsSinceEpoch.toDouble(), 95.0));
          }
        }
      }

      setState(() {
        _graphPoints = points;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching temperature data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = DateTime(picked.year, picked.month, picked.day);
        } else {
          _toDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
      _fetchTemperatureData();
    }
  }

  Color getColorForTemp(double temp) {
    if (temp < 99) return Colors.green;
    if (temp <= 104) return Colors.orange;
    return Colors.red;
  }

  Widget _buildGraph() {
    if (_graphPoints.isEmpty) {
      return const Center(child: Text("No temperature data to display."));
    }

    final minX = _graphPoints.first.x;
    final maxX = _graphPoints.last.x;
    final avgTemp = _graphPoints.map((e) => e.y).reduce((a, b) => a + b) / _graphPoints.length;
    final chartWidth = MediaQuery.of(context).size.width * 4;

    // Find midnight timestamps for vertical separators
    final dayStarts = <DateTime>{};
    for (final point in _graphPoints) {
      final ts = DateTime.fromMillisecondsSinceEpoch(point.x.toInt());
      dayStarts.add(DateTime(ts.year, ts.month, ts.day));
    }

    final verticalDaySeparators = dayStarts
        .where((d) =>
            d.isAfter(DateTime.fromMillisecondsSinceEpoch(minX.toInt())) &&
            d.isBefore(DateTime.fromMillisecondsSinceEpoch(maxX.toInt())))
        .toList();

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.5,
      maxScale: 8.0,
      child: SizedBox(
        width: chartWidth,
        height: 430,
        child: Stack(
          children: [
            LineChart(
              LineChartData(
                minY: 95,
                maxY: 110,
                minX: minX,
                maxX: maxX,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade300, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: const Duration(hours: 4).inMilliseconds.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        if (date.hour == 0) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(DateFormat('MMM d').format(date),
                                style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(date.hour.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      getTitlesWidget: (value, _) =>
                          Text('${value.toStringAsFixed(0)}°'),
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    tooltipRoundedRadius: 8,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                        return LineTooltipItem(
                          "${spot.y.toStringAsFixed(1)}°F\n${DateFormat('MMM d, HH:mm').format(date)}",
                          const TextStyle(color: Colors.white),
                        );
                      }).toList();
                    },
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: avgTemp,
                      color: Colors.purple,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        labelResolver: (_) => 'Avg: ${avgTemp.toStringAsFixed(1)}°',
                        style: const TextStyle(color: Colors.purple),
                      ),
                    ),
                  ],
                  verticalLines: verticalDaySeparators
                      .map((d) => VerticalLine(
                            x: d.millisecondsSinceEpoch.toDouble(),
                            color: Colors.grey.shade600,
                            dashArray: [4, 4],
                            strokeWidth: 1,
                          ))
                      .toList(),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _graphPoints,
                    isCurved: false,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: getColorForTemp(spot.y),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const lightSkyBlue = Color(0xFFD9EDFF);
    return Scaffold(
      appBar: AppBar(
        title: Text('Temperature Graph', style: GoogleFonts.lato()),
        backgroundColor: const Color(0xFF4D8DFF),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _fromDate = null;
                _toDate = null;
              });
              _fetchTemperatureData();
            },
          ),
        ],
      ),
      backgroundColor: lightSkyBlue,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(
                      _fromDate != null
                          ? 'From: ${DateFormat('yMMMd').format(_fromDate!)}'
                          : 'From: -',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(
                      _toDate != null
                          ? 'To: ${DateFormat('yMMMd').format(_toDate!)}'
                          : 'To: -',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildGraph(),
            ),
          ],
        ),
      ),
    );
  }
}
