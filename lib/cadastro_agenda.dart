import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar Firestore

class AgendaSemanalPage extends StatefulWidget {
  const AgendaSemanalPage({super.key});

  @override
  State<AgendaSemanalPage> createState() => _AgendaSemanalPageState();
}

class _AgendaSemanalPageState extends State<AgendaSemanalPage> {
  Map<String, List<String>> _horariosFixosPorDia = {};
  Map<String, Set<String>> _horariosAtivosPorDia = {}; // Usa Set para horários ativos

  final String _agendaDocId = 'minha_agenda'; // ID do documento no Firestore

  @override
  void initState() {
    super.initState();
    _gerarHorariosFixos();
    _carregarAgendaDoFirebase(); // Carrega a agenda ao iniciar a tela
  }

  void _gerarHorariosFixos() {
    _horariosFixosPorDia = {
      'Segunda-feira': [],
      'Terça-feira': [],
      'Quarta-feira': [],
      'Quinta-feira': [],
      'Sexta-feira': [],
    };
    for (var dia in _horariosFixosPorDia.keys) {
      TimeOfDay hora = const TimeOfDay(hour: 8, minute: 0);
      while (hora.hour < 17 || (hora.hour == 17 && hora.minute <= 30)) {
        _horariosFixosPorDia[dia]!
            .add(DateFormat('HH:mm').format(DateTime(2025, 5, 21, hora.hour, hora.minute)));
        if (hora.minute == 0) {
          hora = hora.replacing(minute: 30);
        } else {
          hora = hora.replacing(hour: hora.hour + 1, minute: 0);
        }
      }
      // Garante que 17:30 seja incluído se o loop parar antes
      if (!_horariosFixosPorDia[dia]!.contains('17:30')) {
        _horariosFixosPorDia[dia]!.add('17:30');
      }
    }
  }

  Future<void> _carregarAgendaDoFirebase() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('disponibilidade')
          .doc(_agendaDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _horariosAtivosPorDia.clear(); // Limpa o estado atual antes de carregar
          for (var dia in _horariosFixosPorDia.keys) {
            // Inicializa com um Set vazio se o dia não existir no Firestore
            _horariosAtivosPorDia[dia] = Set<String>();
            if (data.containsKey(dia)) {
              final List<dynamic>? firestoreHorarios = data[dia];
              if (firestoreHorarios != null) {
                // Adiciona apenas horários que são strings
                _horariosAtivosPorDia[dia]!.addAll(firestoreHorarios.map((e) => e.toString()));
              }
            }
          }
        });
      } else {
        // Se o documento não existe, inicializa com todos os horários desmarcados
        _inicializarHorariosAtivosVazios();
      }
    } catch (e) {
      print('Erro ao carregar agenda do Firebase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar agenda: $e')),
      );
      _inicializarHorariosAtivosVazios(); // Garante estado inicial vazio em caso de erro
    }
  }

  void _inicializarHorariosAtivosVazios() {
    setState(() {
      for (var dia in _horariosFixosPorDia.keys) {
        _horariosAtivosPorDia[dia] = Set<String>();
      }
    });
  }

  void _alterarAtividadeHorario(String dia, String horario, bool ativo) {
    setState(() {
      if (ativo) {
        _horariosAtivosPorDia[dia]!.add(horario);
      } else {
        _horariosAtivosPorDia[dia]!.remove(horario);
      }
    });
  }

  void _limparHorariosDia(String dia) {
    setState(() {
      _horariosAtivosPorDia[dia]!.clear();
    });
  }

  Future<void> _salvarAgenda() async {
    try {
      // Converte o Set<String> para List<String> para salvar no Firestore
      Map<String, List<String>> agendaParaSalvar = {};
      _horariosAtivosPorDia.forEach((dia, horariosSet) {
        agendaParaSalvar[dia] = horariosSet.toList();
      });

      await FirebaseFirestore.instance
          .collection('disponibilidade')
          .doc(_agendaDocId)
          .set(agendaParaSalvar, SetOptions(merge: true)); // Use merge para não sobrescrever o documento inteiro

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agenda salva com sucesso!')),
      );
    } catch (e) {
      print('Erro ao salvar agenda no Firebase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar agenda: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Definir Horários da Agenda'),
        centerTitle: true,
        backgroundColor: Colors.blue, // Cor de fundo da AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                children: _horariosFixosPorDia.keys.map((dia) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(dia, style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextButton(
                                onPressed: () => _limparHorariosDia(dia),
                                child: const Text('Limpar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _horariosFixosPorDia[dia]!.map((horario) {
                              final ativo = _horariosAtivosPorDia[dia]?.contains(horario) ?? false;
                              return FilterChip(
                                label: Text(horario),
                                selected: ativo,
                                onSelected: (bool selected) {
                                  _alterarAtividadeHorario(dia, horario, selected);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvarAgenda,
                child: const Text('Salvar Agenda'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}