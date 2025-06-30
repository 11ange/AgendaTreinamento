import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models/horario_model.dart';
import 'services/firestore_service.dart';
import 'controle_pagamentos.dart'; // Reutilizando a classe auxiliar

class EvolucaoPacientePage extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;

  const EvolucaoPacientePage({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  State<EvolucaoPacientePage> createState() => _EvolucaoPacientePageState();
}

class _EvolucaoPacientePageState extends State<EvolucaoPacientePage> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, List<SessaoComData>> _sessoesPorAgendamento = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarSessoesDoPaciente();
  }

  Future<void> _carregarSessoesDoPaciente() async {
    setState(() => _isLoading = true);
    try {
      final sessoes =
          await _firestoreService.getSessoesPorPaciente(widget.pacienteId);

      final sortedEntries = sessoes.entries.toList()
        ..sort((a, b) {
          final dataA = a.value.first.data;
          final dataB = b.value.first.data;
          return dataB.compareTo(dataA); // Mais recentes primeiro
        });

      setState(() {
        _sessoesPorAgendamento = Map.fromEntries(sortedEntries);
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

  Future<void> _editarObservacoes(SessaoComData sessaoComData) async {
    final observacoesController =
        TextEditingController(text: sessaoComData.sessao.observacoes);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Observações da Sessão'),
          content: TextField(
            controller: observacoesController,
            decoration: const InputDecoration(labelText: 'Digite suas anotações'),
            maxLines: 5,
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(observacoesController.text),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _firestoreService.updateObservacoesSessao(
        data: sessaoComData.data,
        agendamentoId: sessaoComData.sessao.agendamentoId,
        observacoes: result,
      );
      _carregarSessoesDoPaciente();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evolução de ${widget.pacienteNome}'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessoesPorAgendamento.isEmpty
              ? const Center(
                  child: Text('Nenhuma sessão encontrada para este paciente.'))
              : RefreshIndicator(
                  onRefresh: _carregarSessoesDoPaciente,
                  child: ListView(
                    children: _sessoesPorAgendamento.entries.map((entry) {
                      final sessoes = entry.value;
                      final dataInicio = sessoes.first.data;
                      final dataFim = sessoes.last.data;
                      final formatoData = DateFormat('dd/MM/yy', 'pt_BR');
                      final periodo =
                          '${formatoData.format(dataInicio)} - ${formatoData.format(dataFim)}';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: ExpansionTile(
                          title: Text(periodo),
                          initiallyExpanded: true,
                          children: sessoes.map((sessaoComData) {
                            final sessao = sessaoComData.sessao;
                            final dataFormatada = DateFormat('dd/MM/yyyy', 'pt_BR')
                                .format(sessaoComData.data);

                            Color statusColor;
                            IconData statusIcon;
                            String statusText = sessao.status;

                            switch (sessao.status) {
                              case 'Realizada':
                                statusColor = Colors.green;
                                statusIcon = Icons.check_circle;
                                break;
                              case 'Faltou':
                                statusColor = Colors.red;
                                statusIcon = Icons.cancel;
                                break;
                              case 'Falta Injustificada':
                                statusColor = Colors.orange;
                                statusIcon = Icons.warning;
                                break;
                              default: // Agendada
                                statusColor = Colors.blue;
                                statusIcon = Icons.schedule;
                            }

                            return ListTile(
                              onTap: () => _editarObservacoes(sessaoComData),
                              leading: Icon(statusIcon, color: statusColor),
                              title: Text('Sessão ${sessao.sessaoNumero} - $dataFormatada'),
                              subtitle: sessao.observacoes != null &&
                                      sessao.observacoes!.isNotEmpty
                                  ? Text(sessao.observacoes!,
                                      maxLines: 1, overflow: TextOverflow.ellipsis)
                                  : const Text('Toque para adicionar observações',
                                      style: TextStyle(fontStyle: FontStyle.italic)),
                              trailing: Text(
                                statusText,
                                style: TextStyle(
                                    color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}