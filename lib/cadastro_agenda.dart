import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgendaSemanalPage extends StatefulWidget {
  const AgendaSemanalPage({super.key});

  @override
  State<AgendaSemanalPage> createState() => _AgendaSemanalPageState();
}

class _AgendaSemanalPageState extends State<AgendaSemanalPage> {
  Map<String, List<String>> _horariosFixosPorDia = {};
  Map<String, Set<String>> _horariosAtivosPorDia = {};

  final String _agendaDocId = 'minha_agenda';

  @override
  void initState() {
    super.initState();
    _gerarHorariosFixos();
    _carregarAgendaDoFirebase();
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
          _horariosAtivosPorDia.clear();
          for (var dia in _horariosFixosPorDia.keys) {
            _horariosAtivosPorDia[dia] = Set<String>();
            if (data.containsKey(dia)) {
              final List<dynamic>? firestoreHorarios = data[dia];
              if (firestoreHorarios != null) {
                _horariosAtivosPorDia[dia]!.addAll(firestoreHorarios.map((e) => e.toString()));
              }
            }
          }
        });
      } else {
        _inicializarHorariosAtivosVazios();
      }
    } catch (e) {
      print('Erro ao carregar agenda do Firebase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar agenda: $e')),
      );
      _inicializarHorariosAtivosVazios();
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
      Map<String, List<String>> agendaParaSalvar = {};
      _horariosAtivosPorDia.forEach((dia, horariosSet) {
        agendaParaSalvar[dia] = horariosSet.toList();
      });

      await FirebaseFirestore.instance
          .collection('disponibilidade')
          .doc(_agendaDocId)
          .set(agendaParaSalvar, SetOptions(merge: true));

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0), 
        child: AppBar(
          title: const Text('Horários de Atendimento'),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                  // =======================================================================
                  // ALTERAÇÃO: Substituindo o Wrap por um GridView.count
                  // =======================================================================
                  GridView.count(
                    crossAxisCount: 3, // Define 3 colunas
                    crossAxisSpacing: 8.0, // Espaçamento horizontal
                    mainAxisSpacing: 4.0, // Espaçamento vertical
                    childAspectRatio: 2.5, // Proporção do botão (largura / altura)
                    shrinkWrap: true, // Para o GridView caber dentro do ListView
                    physics: const NeverScrollableScrollPhysics(), // Impede a rolagem do GridView
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
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvarAgenda,
              child: const Text('Salvar Agenda'),
            ),
          ),
        ),
      ],
    );
  }
}