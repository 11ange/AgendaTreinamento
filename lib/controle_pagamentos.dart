// 11ange/agendatreinamento/AgendaTreinamento-f667d20bbd422772da4aba80e9e5223229c98088/lib/controle_pagamentos.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models/horario_model.dart';

class ControlePagamentosPage extends StatefulWidget {
  const ControlePagamentosPage({super.key});

  @override
  State<ControlePagamentosPage> createState() => _ControlePagamentosPageState();
}

class _ControlePagamentosPageState extends State<ControlePagamentosPage> {
  Map<String, List<SessaoAgendada>> _sessoesPorPaciente = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarSessoes();
  }

  Future<void> _carregarSessoes() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('sessoes_agendadas').get();
      
      final Map<String, List<SessaoAgendada>> sessoesAgrupadas = {};

      for (var doc in snapshot.docs) {
        final sessoesDoDia = doc.data()['sessoes'] as Map<String, dynamic>;
        sessoesDoDia.forEach((hora, sessaoData) {
          final sessao = SessaoAgendada.fromMap(sessaoData as Map<String, dynamic>);
          
          if(sessao.status == 'Agendada') { // Considerar apenas sessões agendadas
            if (sessoesAgrupadas.containsKey(sessao.pacienteNome)) {
              sessoesAgrupadas[sessao.pacienteNome]!.add(sessao);
            } else {
              sessoesAgrupadas[sessao.pacienteNome] = [sessao];
            }
          }
        });
      }

      // Ordenar as sessões de cada paciente por data
      sessoesAgrupadas.forEach((key, value) {
        value.sort((a, b) => a.agendamentoStartDate.compareTo(b.agendamentoStartDate));
      });

      setState(() {
        _sessoesPorPaciente = sessoesAgrupadas;
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar sessões: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Pagamentos'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessoesPorPaciente.isEmpty
              ? const Center(child: Text('Nenhuma sessão agendada encontrada.'))
              : ListView.builder(
                  itemCount: _sessoesPorPaciente.keys.length,
                  itemBuilder: (context, index) {
                    final pacienteNome = _sessoesPorPaciente.keys.elementAt(index);
                    final sessoes = _sessoesPorPaciente[pacienteNome]!;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ExpansionTile(
                        title: Text(pacienteNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: sessoes.map((sessao) {
                          // Formatar a data da sessão específica
                          // A data de início é a mesma para todas as sessões do mesmo agendamento,
                          // mas o dia real da semana muda. Precisamos calcular a data correta.
                           final dataSessao = sessao.agendamentoStartDate.toDate().add(Duration(days: (sessao.sessaoNumero - 1) * 7));
                           final dataFormatada = DateFormat('dd/MM/yyyy').format(dataSessao);

                          return ListTile(
                            title: Text('Sessão ${sessao.sessaoNumero}/${sessao.totalSessoes} - $dataFormatada'),
                            trailing: Text(
                              sessao.statusPagamento ?? 'N/A',
                              style: TextStyle(
                                color: (sessao.statusPagamento == 'Pendente') ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
    );
  }
}