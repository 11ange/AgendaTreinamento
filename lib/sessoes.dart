import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class Sessoes extends StatefulWidget {
  const Sessoes({super.key});

  @override
  State<Sessoes> createState() => _SessoesState();
}

class _SessoesState extends State<Sessoes> {
  final String _disponibilidadeCollectionName = 'disponibilidade';
  final String _disponibilidadeDocId = 'minha_agenda';
  final String _sessoesAgendadasCollectionName = 'sessoes_agendadas';

  Map<String, List<String>> _horariosDisponibilidadePadrao = {};

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<String> _horariosParaExibir = [];

  bool _isLoadingDisponibilidadePadrao = true;
  bool _isLoadingSessoesDoDia = false;

  @override
  void initState() {
    super.initState();
    _carregarDisponibilidadePadraoDoFirebase().then((_) {
      _selectedDay = _focusedDay;
      _atualizarHorariosParaExibir(_selectedDay!);
    });
  }

  Future<void> _carregarDisponibilidadePadraoDoFirebase() async {
    setState(() {
      _isLoadingDisponibilidadePadrao = true;
    });
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection(_disponibilidadeCollectionName)
          .doc(_disponibilidadeDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _horariosDisponibilidadePadrao.clear();
        data.forEach((dia, horarios) {
          if (horarios is List) {
            _horariosDisponibilidadePadrao[dia] =
                List<String>.from(horarios.map((e) => e.toString()))..sort();
          }
        });
      }
    } catch (e) {
      print('Erro ao carregar disponibilidade padrão: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar disponibilidade padrão: $e')),
      );
    } finally {
      setState(() {
        _isLoadingDisponibilidadePadrao = false;
      });
    }
  }

  Future<List<String>> _carregarSessoesDoDia(DateTime dia) async {
    setState(() {
      _isLoadingSessoesDoDia = true;
    });
    List<String> sessoesDoDia = [];
    try {
      String docId = DateFormat('yyyy-MM-dd').format(dia);
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection(_sessoesAgendadasCollectionName)
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('horarios') && data['horarios'] is List) {
          sessoesDoDia = List<String>.from(data['horarios'].map((e) => e.toString()))..sort();
        }
      }
    } catch (e) {
      print('Erro ao carregar sessões do dia $dia: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar sessões do dia: $e')),
      );
    } finally {
      setState(() {
        _isLoadingSessoesDoDia = false;
      });
    }
    return sessoesDoDia;
  }

  String _getNomeDiaDaSemana(DateTime data) {
    String dia = DateFormat('EEEE', 'pt_PT').format(data);
    return dia[0].toUpperCase() + dia.substring(1);
  }

  Future<void> _atualizarHorariosParaExibir(DateTime dia) async {
    if (_isLoadingDisponibilidadePadrao) return;

    List<String> sessoes = await _carregarSessoesDoDia(dia);

    setState(() {
      if (sessoes.isNotEmpty) {
        _horariosParaExibir = sessoes;
      } else {
        String nomeDiaSemana = _getNomeDiaDaSemana(dia);
        _horariosParaExibir = _horariosDisponibilidadePadrao[nomeDiaSemana] ?? [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessões'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Card(
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  if (_selectedDay != null) {
                    _atualizarHorariosParaExibir(_selectedDay!);
                  }
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mês',
                },
                calendarStyle: CalendarStyle( // <--- REMOVIDO o 'const' AQUI
                  selectedDecoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration( // <--- REMOVIDO o 'const' AQUI
                    color: Colors.blue.shade200, // LINHA DO ERRO, AGORA DEVE FUNCIONAR
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                locale: 'pt_PT',
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoadingDisponibilidadePadrao || _isLoadingSessoesDoDia
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedDay == null
                      ? const Center(child: Text('Selecione um dia para ver a disponibilidade.'))
                      : (_horariosParaExibir.isEmpty)
                          ? const Center(child: Text('Nenhuma sessão agendada ou disponibilidade para este dia.'))
                          : Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: _horariosParaExibir.map((horario) {
                                return Chip(
                                  label: Text(horario),
                                  backgroundColor: Colors.blue.shade100, // Esta linha também não deve ter 'const'
                                );
                              }).toList(),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}