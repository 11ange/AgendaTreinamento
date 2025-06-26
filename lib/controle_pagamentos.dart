import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models/horario_model.dart';
import 'services/firestore_service.dart';

// Classe auxiliar para armazenar a sessão junto com sua data específica
class SessaoComData {
  final SessaoAgendada sessao;
  final DateTime data;

  SessaoComData(this.sessao, this.data);
}

class ControlePagamentosPage extends StatefulWidget {
  const ControlePagamentosPage({super.key});

  @override
  State<ControlePagamentosPage> createState() => _ControlePagamentosPageState();
}

class _ControlePagamentosPageState extends State<ControlePagamentosPage> {
  final FirestoreService _firestoreService = FirestoreService();
  // Estrutura de dados alterada para usar a classe auxiliar
  Map<String, List<SessaoComData>> _sessoesPorAgendamento = {};
  Map<String, String> _horaPorAgendamento = {};
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
      
      final Map<String, List<SessaoComData>> sessoesAgrupadas = {};
      final Map<String, String> horaAgrupada = {};

      for (var doc in snapshot.docs) {
        if (!doc.exists || !doc.data().containsKey('sessoes')) continue;
        
        final dataDaSessao = DateFormat('yyyy-MM-dd').parse(doc.id);
        final sessoesDoDia = doc.data()['sessoes'] as Map<String, dynamic>;

        sessoesDoDia.forEach((hora, sessaoData) {
          final sessao = SessaoAgendada.fromMap(sessaoData as Map<String, dynamic>);
          
          if ((sessao.status == 'Agendada' || sessao.status == 'Desmarcada') && sessao.agendamentoId.isNotEmpty) {
            final sessaoComData = SessaoComData(sessao, dataDaSessao);

            horaAgrupada.putIfAbsent(sessao.agendamentoId, () => hora);
            if (sessoesAgrupadas.containsKey(sessao.agendamentoId)) {
              sessoesAgrupadas[sessao.agendamentoId]!.add(sessaoComData);
            } else {
              sessoesAgrupadas[sessao.agendamentoId] = [sessaoComData];
            }
          }
        });
      }

      sessoesAgrupadas.forEach((key, value) {
        value.sort((a, b) => a.data.compareTo(b.data));
      });

      setState(() {
        _sessoesPorAgendamento = sessoesAgrupadas;
        _horaPorAgendamento = horaAgrupada;
        _isLoading = false;
      });

    } catch (e, s) {
      print('Erro ao carregar sessões: $e');
      print(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar sessões: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showConvenioPopup(List<SessaoAgendada> sessoesGuia) async {
    final sessaoBase = sessoesGuia.first;
    final bool isPago = sessaoBase.dataPagamentoGuia != null;
    final dataPagamentoController = TextEditingController(
      text: isPago ? DateFormat('dd/MM/yyyy').format(sessaoBase.dataPagamentoGuia!.toDate()) : '',
    );

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pagamento Convênio: ${sessaoBase.pacienteNome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Guia enviada para o convênio."),
              const SizedBox(height: 16),
              TextFormField(
                controller: dataPagamentoController,
                decoration: const InputDecoration(
                  labelText: 'Data do Pagamento',
                  hintText: 'DD/MM/AAAA',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: sessaoBase.dataPagamentoGuia?.toDate() ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    locale: const Locale('pt', 'BR'),
                  );
                  if (pickedDate != null) {
                    dataPagamentoController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
                  }
                },
              ),
            ],
          ),
          actions: [
            if (isPago)
              TextButton(
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar Cancelamento'),
                      content: const Text('Deseja realmente cancelar este pagamento e reverter o status para "Pendente"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Não')),
                        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sim, Cancelar')),
                      ],
                    ),
                  );

                  if (confirmar == true) {
                    await _firestoreService.cancelarPagamentoGuiaConvenio(agendamentoId: sessaoBase.agendamentoId);
                    Navigator.of(context).pop();
                    _carregarSessoes();
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cancelar Pagamento'),
              ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
            ElevatedButton(
              onPressed: () async {
                if (dataPagamentoController.text.isNotEmpty) {
                  final data = DateFormat('dd/MM/yyyy').parse(dataPagamentoController.text);
                  await _firestoreService.atualizarPagamentoGuiaConvenio(
                    agendamentoId: sessaoBase.agendamentoId,
                    dataPagamento: Timestamp.fromDate(data),
                  );
                  Navigator.of(context).pop();
                  _carregarSessoes(); 
                }
              },
              child: Text(isPago ? 'Atualizar' : 'Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showParcelaPopup(SessaoAgendada sessaoBase, int parcela) async {
    final pagamentos = sessaoBase.pagamentosParcelados ?? {};
    final bool isPaga = pagamentos[parcela.toString()] != null;
    final dataPagamentoController = TextEditingController(
      text: isPaga ? DateFormat('dd/MM/yyyy').format((pagamentos[parcela.toString()] as Timestamp).toDate()) : '',
    );

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$parcelaª Parcela - ${sessaoBase.pacienteNome}'),
          content: TextFormField(
            controller: dataPagamentoController,
            decoration: const InputDecoration(
              labelText: 'Data do Pagamento', hintText: 'DD/MM/AAAA',
              border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              final initialDate = isPaga ? (pagamentos[parcela.toString()] as Timestamp).toDate() : DateTime.now();
              DateTime? pickedDate = await showDatePicker(
                context: context, initialDate: initialDate,
                firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('pt', 'BR'),
              );
              if (pickedDate != null) {
                dataPagamentoController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
              }
            },
          ),
          actions: [
            if (isPaga)
              TextButton(
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar Cancelamento'),
                      content: const Text('Deseja realmente cancelar o pagamento desta parcela?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Não')),
                        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sim, Cancelar')),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    await _firestoreService.cancelarPagamentoParcela(agendamentoId: sessaoBase.agendamentoId, parcela: parcela);
                    Navigator.of(context).pop();
                    _carregarSessoes();
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cancelar Pagamento'),
              ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
            ElevatedButton(
              onPressed: () async {
                if (dataPagamentoController.text.isNotEmpty) {
                  final data = DateFormat('dd/MM/yyyy').parse(dataPagamentoController.text);
                  await _firestoreService.atualizarPagamentoParcela(
                    agendamentoId: sessaoBase.agendamentoId,
                    parcela: parcela,
                    dataPagamento: Timestamp.fromDate(data),
                  );
                  Navigator.of(context).pop();
                  _carregarSessoes();
                }
              },
              child: Text(isPaga ? 'Atualizar' : 'Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSessaoUnicaPopup(SessaoAgendada sessao) async {
    final bool isPaga = sessao.statusPagamento == 'Pago';
    final dataPagamentoController = TextEditingController(
      text: isPaga && sessao.dataPagamentoSessao != null
          ? DateFormat('dd/MM/yyyy').format(sessao.dataPagamentoSessao!.toDate())
          : '',
    );

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pagamento Sessão ${sessao.sessaoNumero} - ${sessao.pacienteNome}'),
          content: TextFormField(
            controller: dataPagamentoController,
            decoration: const InputDecoration(
              labelText: 'Data do Pagamento', hintText: 'DD/MM/AAAA',
              border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              final initialDate = isPaga && sessao.dataPagamentoSessao != null 
                  ? sessao.dataPagamentoSessao!.toDate() 
                  : DateTime.now();
              DateTime? pickedDate = await showDatePicker(
                context: context, initialDate: initialDate,
                firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('pt', 'BR'),
              );
              if (pickedDate != null) {
                dataPagamentoController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
              }
            },
          ),
          actions: [
            if (isPaga)
              TextButton(
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar Cancelamento'),
                      content: const Text('Deseja realmente cancelar o pagamento desta sessão?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Não')),
                        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sim, Cancelar')),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    await _firestoreService.cancelarPagamentoSessaoUnica(
                      sessao: sessao,
                      hora: _horaPorAgendamento[sessao.agendamentoId]!,
                    );
                    Navigator.of(context).pop();
                    _carregarSessoes();
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cancelar Pagamento'),
              ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
            ElevatedButton(
              onPressed: () async {
                if (dataPagamentoController.text.isNotEmpty) {
                  final data = DateFormat('dd/MM/yyyy').parse(dataPagamentoController.text);
                  await _firestoreService.atualizarPagamentoSessaoUnica(
                    sessao: sessao,
                    dataPagamento: Timestamp.fromDate(data),
                    hora: _horaPorAgendamento[sessao.agendamentoId]!,
                  );
                  Navigator.of(context).pop();
                  _carregarSessoes();
                }
              },
              child: Text(isPaga ? 'Atualizar' : 'Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Pagamentos'),
        backgroundColor: Colors.blue, // Cor de fundo da AppBar
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessoesPorAgendamento.isEmpty
              ? const Center(child: Text('Nenhuma sessão encontrada para pagamento.'))
              : RefreshIndicator(
                  onRefresh: _carregarSessoes,
                  child: ListView.builder(
                    itemCount: _sessoesPorAgendamento.keys.length,
                    itemBuilder: (context, index) {
                      final agendamentoId = _sessoesPorAgendamento.keys.elementAt(index);
                      final sessoesComData = _sessoesPorAgendamento[agendamentoId]!;
                      final sessaoRef = sessoesComData.first.sessao;
                      final pacienteNome = sessaoRef.pacienteNome;
                      
                      final dataInicio = sessoesComData.first.data;
                      final dataFim = sessoesComData.last.data;
                      final formatoData = DateFormat('dd/MM/yy', 'pt_BR');
                      // =======================================================================
                      // LÓGICA ADICIONADA: Captura a hora do agendamento
                      // =======================================================================
                      final horaAgendamento = _horaPorAgendamento[agendamentoId] ?? '';
                      final periodo = '${formatoData.format(dataInicio)} - ${formatoData.format(dataFim)} às $horaAgendamento';

                      if (sessaoRef.formaPagamento == 'Convênio') {
                         final sessoesDeConvenio = sessoesComData.map((scd) => scd.sessao).toList();
                        final status = sessaoRef.dataPagamentoGuia != null ? 'Recebido' : 'Pendente';
                        final dataPagamento = sessaoRef.dataPagamentoGuia != null
                            ? DateFormat('dd/MM/yyyy', 'pt_BR').format(sessaoRef.dataPagamentoGuia!.toDate().toLocal())
                            : 'N/A';
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: ListTile(
                            title: Text(pacienteNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(periodo, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('Convênio: ${sessaoRef.convenio ?? 'Não informado'}'),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: status == 'Recebido' ? Colors.green : Colors.orange)),
                                Text(dataPagamento, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            onTap: () => _showConvenioPopup(sessoesDeConvenio),
                          ),
                        );
                      }
                      
                      if (sessaoRef.parcelamento == '3x') {
                        final pagamentos = sessaoRef.pagamentosParcelados ?? {};
                        final bool todasPagas = pagamentos['1'] != null && pagamentos['2'] != null && pagamentos['3'] != null;
                        final statusGlobal = todasPagas ? 'Pago' : 'Pendente';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: ExpansionTile(
                            title: Text(pacienteNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(periodo, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text("Pagamento: ${sessaoRef.formaPagamento} - 3x"),
                              ],
                            ),
                            trailing: Text(
                              statusGlobal,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusGlobal == 'Pago' ? Colors.green : Colors.red,
                              ),
                            ),
                            children: List.generate(3, (i) {
                              final parcelaNum = i + 1;
                              final statusParcela = pagamentos[parcelaNum.toString()] != null ? 'Pago' : 'Pendente';
                              final dataPagamentoParcela = pagamentos[parcelaNum.toString()] != null 
                                  ? DateFormat('dd/MM/yyyy', 'pt_BR').format((pagamentos[parcelaNum.toString()] as Timestamp).toDate().toLocal()) 
                                  : 'N/A';

                              return ListTile(
                                dense: true,
                                title: Text('$parcelaNumª Parcela'),
                                trailing: Text(
                                  '$statusParcela - $dataPagamentoParcela',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: statusParcela == 'Pago' ? Colors.green : Colors.red,
                                  ),
                                ),
                                onTap: () => _showParcelaPopup(sessaoRef, parcelaNum),
                              );
                            }),
                          ),
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: ExpansionTile(
                          title: Text(pacienteNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(periodo, style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text("Pagamento: ${sessaoRef.formaPagamento ?? 'N/A'} - Por Sessão"),
                            ],
                          ),
                          children: sessoesComData.map((sessaoComData) {
                             final sessao = sessaoComData.sessao;
                             final dataFormatada = DateFormat('dd/MM/yyyy', 'pt_BR').format(sessaoComData.data);
                             final statusPagamento = sessao.statusPagamento ?? 'Pendente';
                             final isDesmarcada = sessao.status == 'Desmarcada';

                            return ListTile(
                              onTap: isDesmarcada ? null : () => _showSessaoUnicaPopup(sessao),
                              tileColor: isDesmarcada ? Colors.grey.shade300 : null,
                              title: Text(
                                'Sessão ${sessao.sessaoNumero} - $dataFormatada',
                                style: TextStyle(
                                  decoration: isDesmarcada ? TextDecoration.lineThrough : TextDecoration.none,
                                ),
                              ),
                              trailing: Text(
                                isDesmarcada ? 'Desmarcada' : statusPagamento,
                                style: TextStyle(
                                  color: isDesmarcada
                                    ? Colors.grey.shade700
                                    : (statusPagamento == 'Pago' ? Colors.green : Colors.red),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}