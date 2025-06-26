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

      // Ordena os agendamentos pela data de início da primeira sessão (mais recente primeiro)
      final sortedEntries = sessoes.entries.toList()
        ..sort((a, b) {
          final dataA = a.value.first.data;
          final dataB = b.value.first.data;
          return dataB.compareTo(dataA);
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

  Future<void> _atualizarStatusSessao(
      SessaoComData sessaoComData, String novoStatus) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Alteração'),
        content: Text('Deseja alterar o status desta sessão para "$novoStatus"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim')),
        ],
      ),
    );

    if (confirmar == true) {
      await _firestoreService.updateStatusSessao(
        data: sessaoComData.data,
        agendamentoId: sessaoComData.sessao.agendamentoId,
        novoStatus: novoStatus,
      );
      _carregarSessoesDoPaciente(); // Recarrega para refletir a alteração
    }
  }

  Future<void> _editarObservacoes(SessaoComData sessaoComData) async {
    final observacoesController =
        TextEditingController(text: sessaoComData.sessao.observacoes);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Observações da Sessão'),
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
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessoesPorAgendamento.isEmpty
              ? const Center(
                  child: Text('Nenhuma sessão encontrada para este paciente.'))
              : ListView(
                  children: _sessoesPorAgendamento.entries.map((entry) {
                    final agendamentoId = entry.key;
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
                          final dataFormatada =
                              DateFormat('dd/MM/yyyy', 'pt_BR')
                                  .format(sessaoComData.data);

                          Color statusColor;
                          IconData statusIcon;
                          switch (sessao.status) {
                            case 'Realizada':
                              statusColor = Colors.green;
                              statusIcon = Icons.check_circle;
                              break;
                            case 'Faltou':
                              statusColor = Colors.red;
                              statusIcon = Icons.cancel;
                              break;
                            case 'Desmarcada':
                              statusColor = Colors.grey;
                              statusIcon = Icons.info_outline;
                              break;
                            default: // Agendada
                              statusColor = Colors.blue;
                              statusIcon = Icons.schedule;
                          }

                          return ListTile(
                            onTap: () => _editarObservacoes(sessaoComData),
                            leading: Icon(statusIcon, color: statusColor),
                            title: Text(
                                'Sessão ${sessao.sessaoNumero} - $dataFormatada'),
                            subtitle: sessao.observacoes != null &&
                                    sessao.observacoes!.isNotEmpty
                                ? Text(sessao.observacoes!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)
                                : const Text('Sem observações',
                                    style:
                                        TextStyle(fontStyle: FontStyle.italic)),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                _atualizarStatusSessao(sessaoComData, value);
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'Realizada',
                                  child: Text('Realizada'),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'Faltou',
                                  child: Text('Faltou'),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}