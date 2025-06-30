import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'services/firestore_service.dart';
import 'models/horario_model.dart';

// Enum para as opções de desmarque
enum DesmarcarOpcao { apenasEsta, estaEFuturas, cancelar }

class Sessoes extends StatefulWidget {
  const Sessoes({super.key});

  @override
  State<Sessoes> createState() => _SessoesState();
}

class _SessoesState extends State<Sessoes> {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<String>> _horariosDisponibilidadePadrao = {};
  DateTime _focusedDay = DateTime.now().toUtc();
  DateTime? _selectedDay;
  List<Horario> _horariosDoDia = [];
  Map<String, Color> _dayColors = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'pt_BR';
    _selectedDay = _focusedDay;
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadDataForDay(_selectedDay!);
    await _fetchColorsForMonth(_focusedDay);
  }

  Future<void> _loadDataForDay(DateTime day) async {
    setState(() => _isLoading = true);
    try {
      if (_horariosDisponibilidadePadrao.isEmpty) {
        _horariosDisponibilidadePadrao =
            await _firestoreService.getDisponibilidadePadrao();
      }
      _horariosDoDia = await _firestoreService.getHorariosParaDia(
          day, _horariosDisponibilidadePadrao);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao carregar dados: $e")));
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchColorsForMonth(DateTime month) async {
    if (_horariosDisponibilidadePadrao.isEmpty) {
      _horariosDisponibilidadePadrao =
          await _firestoreService.getDisponibilidadePadrao();
    }
    Map<String, Color> newColors = {};
    DateTime firstDay = DateTime.utc(month.year, month.month, 1);
    DateTime lastDay = DateTime.utc(month.year, month.month + 1, 0);

    for (var day = firstDay;
        day.isBefore(lastDay.add(const Duration(days: 1)));
        day = day.add(const Duration(days: 1))) {
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final dayOfWeek = _getNomeDiaDaSemana(day);
      final totalSlots = _horariosDisponibilidadePadrao[dayOfWeek]?.length ?? 0;
      if (totalSlots == 0) continue;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('sessoes_agendadas')
            .doc(dateKey)
            .get();
        final docData = doc.data() as Map<String, dynamic>?;
        final sessoesDoDia =
            (doc.exists && docData != null && docData.containsKey('sessoes'))
                ? docData['sessoes'] as Map<String, dynamic>
                : <String, dynamic>{};
        int bookedCount = sessoesDoDia.values
            .where((s) => s['status'] == 'Agendada' || s['status'] == 'Bloqueado')
            .length;
        if (bookedCount >= totalSlots) {
          newColors[dateKey] = Colors.red.shade300;
        } else if (bookedCount > 0) {
          newColors[dateKey] = Colors.yellow.shade400;
        } else {
          newColors[dateKey] = Colors.green.shade300;
        }
      } catch (e) {
        print("Erro ao buscar cor para o dia $dateKey: $e");
      }
    }
    if (mounted) {
      setState(() => _dayColors = newColors);
    }
  }

  Future<void> _reloadDataAfterAction() async {
    setState(() => _isLoading = true);
    await _fetchColorsForMonth(_focusedDay);
    await _loadDataForDay(_selectedDay!);
    setState(() => _isLoading = false);
  }

  Future<void> _handleAction(String action, Horario horario) async {
    // Lógica especial para desmarcar
    if (action == 'Desmarcada') {
      final opcao = await _showDesmarcarOptionsDialog();
      if (opcao == null || opcao == DesmarcarOpcao.cancelar) return;

      setState(() => _isSaving = true);
      try {
        if (opcao == DesmarcarOpcao.apenasEsta) {
          await _firestoreService.desmarcarSessaoUnicaEReagendar(
              data: _selectedDay!, hora: horario.hora);
        } else { // estaEFuturas
          await _firestoreService.desmarcarSessoesRestantes(
              data: _selectedDay!, hora: horario.hora);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão(ões) desmarcada(s) com sucesso!')),
        );
        await _reloadDataAfterAction();
      } catch (e, s) {
        print("Erro ao desmarcar: $e\n$s");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }
    
    // Lógica para Remarcar uma sessão desmarcada
    if (action == 'Remarcar') {
      final confirm = await _showConfirmationDialog("Confirmar Ação", "Deseja reativar esta sessão? Isso removerá uma sessão do final do bloco para manter a contagem.");
      if (confirm != true) return;

      setState(() => _isSaving = true);
      try {
          await _firestoreService.reativarSessaoDesmarcada(data: _selectedDay!, hora: horario.hora);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão reativada com sucesso!')));
          await _reloadDataAfterAction();
      } catch (e,s) {
          print("Erro ao reativar sessão: $e\n$s");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
      } finally {
          if (mounted) setState(() => _isSaving = false);
      }
      return;
    }
    
    // Lógica para desfazer status de Falta Injustificada
    if (action == 'desfazer_status' && horario.status == 'Falta Injustificada') {
        final confirm = await _showConfirmationDialog("Confirmar Ação", "Deseja reverter a 'Falta Injustificada'? A sessão extra adicionada ao final será removida.");
        if(confirm != true) return;

        setState(() => _isSaving = true);
        try {
            await _firestoreService.cancelarFaltaInjustificada(dataSessao: _selectedDay!, hora: horario.hora);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ação desfeita com sucesso!')));
            await _reloadDataAfterAction();
        } catch(e,s) {
            print("Erro ao cancelar falta injustificada: $e\n$s");
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
        } finally {
            if (mounted) setState(() => _isSaving = false);
        }
        return;
    }

    // Lógica para outras ações
    final confirm =
        await _showConfirmationDialog(_getDialogTitle(action), _getDialogContent(action));
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      switch (action) {
        case 'Realizada':
        case 'Faltou':
          await _firestoreService.updateStatusSessao(
              data: _selectedDay!, hora: horario.hora, novoStatus: action);
          break;
        case 'Falta Injustificada':
          await _firestoreService.registrarFaltaInjustificada(
              dataSessaoFaltou: _selectedDay!, hora: horario.hora);
          break;
        case 'pagar':
          await _firestoreService.updatePagamentoSessao(
              data: _selectedDay!, hora: horario.hora, pago: true);
          break;
        case 'desfazer_pagamento':
          await _firestoreService.updatePagamentoSessao(
              data: _selectedDay!, hora: horario.hora, pago: false);
          break;
        case 'desfazer_status': // Caso geral
          await _firestoreService.updateStatusSessao(
              data: _selectedDay!, hora: horario.hora, novoStatus: 'Agendada');
          break;
        case 'bloquear':
          await _firestoreService.bloquearHorario(_selectedDay!, horario.hora);
          break;
        case 'desbloquear':
          await _firestoreService.desbloquearHorario(_selectedDay!, horario.hora);
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ação realizada com sucesso!')),
      );
      await _reloadDataAfterAction();
    } catch (e, s) {
      print("Erro ao executar ação '$action': $e\n$s");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleBloquearDiaInteiro() async {
    final confirmar = await _showConfirmationDialog(
        "Bloquear Dia", "Tem certeza que deseja bloquear todos os horários disponíveis de hoje?");
    if (confirmar != true) return;
    setState(() => _isSaving = true);
    try {
      final horariosParaBloquear =
          _horariosDoDia.where((h) => h.status == 'disponivel').map((h) => h.hora).toList();
      if (horariosParaBloquear.isNotEmpty) {
        await _firestoreService.bloquearHorariosEmLote(
            _selectedDay!, horariosParaBloquear);
      }
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horários disponíveis bloqueados!')));
      await _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao bloquear horários: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDesbloquearDiaInteiro() async {
    final confirmar = await _showConfirmationDialog("Desbloquear Dia",
        "Tem certeza que deseja desbloquear todos os horários bloqueados de hoje?");
    if (confirmar != true) return;
    setState(() => _isSaving = true);
    try {
      final horariosParaDesbloquear =
          _horariosDoDia.where((h) => h.status == 'Bloqueado').map((h) => h.hora).toList();
      if (horariosParaDesbloquear.isNotEmpty) {
        await _firestoreService.desbloquearHorariosEmLote(
            _selectedDay!, horariosParaDesbloquear);
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Horários bloqueados removidos!')));
      await _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desbloquear horários: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0),
        child: AppBar(
          title: const Text('Sessões'),
          centerTitle: true,
        ),
      ),
      body: Column(
        children: [
          Card(margin: const EdgeInsets.all(8.0), child: _buildTableCalendar()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: ElevatedButton(
                      child: const FittedBox(child: Text("Bloquear dia")),
                      onPressed: _isLoading || _isSaving ? null : _handleBloquearDiaInteiro,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade700,
                          foregroundColor: Colors.white),
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: ElevatedButton(
                      child: const FittedBox(child: Text("Desbloquear dia")),
                      onPressed: _isLoading || _isSaving ? null : _handleDesbloquearDiaInteiro,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white),
                    )),
                  ],
                ),
                if (_selectedDay != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR').format(_selectedDay!),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildHorariosList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHorariosList() {
    if (_horariosDoDia.isEmpty) {
      return const Center(
          child: Text("Nenhum horário de trabalho definido para este dia."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _horariosDoDia.length,
      itemBuilder: (context, index) {
        final horario = _horariosDoDia[index];
        return _buildHorarioListItem(horario);
      },
    );
  }

  Widget _buildHorarioListItem(Horario horario) {
    Color cardColor = Colors.white;
    Widget title = const Text("");
    Widget? subtitle;
    List<Widget> actions = [];

    final sessao = horario.sessaoAgendada;
    final isPago = sessao?.statusPagamento == 'Pago';

    switch (horario.status) {
      case 'disponivel':
        cardColor = Colors.green.shade100;
        title = const Text("Horário Disponível",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
        actions = [
          TextButton(
              child: const Text("Agendar"),
              onPressed: () async {
                final agendou = await _showAgendamentoPopup(context, horario.hora);
                if (agendou == true) await _reloadDataAfterAction();
              }),
          IconButton(
              icon: const Icon(Icons.block, color: Colors.grey, size: 20),
              tooltip: "Bloquear",
              onPressed: () => _handleAction('bloquear', horario)),
        ];
        break;

      case 'Desmarcada':
        cardColor = Colors.amber.shade100;
        title = Text(horario.pacienteNome ?? 'Paciente', style: const TextStyle(decoration: TextDecoration.lineThrough));
        subtitle = const Text("Sessão desmarcada");
        actions = [
          TextButton(
            child: const Text("Remarcar"),
            onPressed: () => _handleAction('Remarcar', horario),
          ),
        ];
        break;

      case 'Agendada':
      case 'Realizada':
      case 'Faltou':
      case 'Falta Injustificada':
        cardColor = _getColorForStatus(horario.status);
        title = Text(horario.pacienteNome ?? 'Paciente');
        subtitle = Text(
          "Sessão ${horario.sessaoNumero}/${horario.totalSessoes} - ${horario.status}",
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );
        actions = [
          if (isPago) const Icon(Icons.paid, color: Colors.green, size: 20),
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(value, horario),
            itemBuilder: (context) {
              List<PopupMenuEntry<String>> items = [];
              if (horario.status == 'Agendada') {
                items.add(const PopupMenuItem(
                    value: 'Realizada', child: Text('Confirmar Presença')));
                items.add(
                    const PopupMenuItem(value: 'Faltou', child: Text('Confirmar Falta')));
                items.add(const PopupMenuDivider());
                items.add(const PopupMenuItem(
                    value: 'Desmarcada', child: Text('Desmarcar Sessão')));
                items.add(const PopupMenuItem(
                    value: 'Falta Injustificada', child: Text('Falta Injustificada')));
              } else {
                items.add(const PopupMenuItem(
                    value: 'desfazer_status', child: Text('Desfazer Status')));
              }
              if (sessao?.formaPagamento != 'Convênio' && sessao?.formaPagamento != null) {
                items.add(const PopupMenuDivider());
                if (isPago) {
                  items.add(const PopupMenuItem(
                      value: 'desfazer_pagamento', child: Text('Desfazer Pagamento')));
                } else {
                  items.add(const PopupMenuItem(
                      value: 'pagar', child: Text('Marcar como Pago')));
                }
              }
              return items;
            },
          ),
        ];
        break;

      case 'Bloqueado':
        cardColor = Colors.grey.shade300;
        title = const Text("Horário Bloqueado",
            style: TextStyle(fontStyle: FontStyle.italic));
        actions = [
          IconButton(
              icon: const Icon(Icons.lock_open, color: Colors.green, size: 20),
              tooltip: "Desbloquear",
              onPressed: () => _handleAction('desbloquear', horario)),
        ];
        break;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            Text(horario.hora,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, if (subtitle != null) subtitle],
              ),
            ),
            if (_isSaving)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3))
            else
              Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showAgendamentoPopup(BuildContext context, String hora) {
    final formKey = GlobalKey<FormState>();
    final quantidadeSessoesController = TextEditingController(text: '10');
    final convenioController = TextEditingController();

    String? selectedPacienteId;
    String? selectedPacienteNome;
    String? formaPagamentoValue;
    String? parcelamentoValue;

    // Carrega a lista de pacientes uma única vez ao abrir o diálogo
    final pacientesFuture = _firestoreService.getPacientesSemAgendamentoAtivo();

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: Text('Novo Agendamento - $hora'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      FutureBuilder<List<QueryDocumentSnapshot>>(
                        future: pacientesFuture, // Usa o future pré-carregado
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Nenhum paciente disponível para agendamento.", textAlign: TextAlign.center),
                            );
                          }
                          return DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Paciente',
                                border: OutlineInputBorder(),
                                isDense: true),
                            items: snapshot.data!
                                .map((doc) => DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: Text(doc['nome'], overflow: TextOverflow.ellipsis),
                                      onTap: () => selectedPacienteNome = doc['nome'],
                                    ))
                                .toList(),
                            onChanged: (value) => selectedPacienteId = value,
                            validator: (v) =>
                                v == null ? 'Selecione um paciente' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: quantidadeSessoesController,
                        decoration: const InputDecoration(
                            labelText: 'Quantidade de Sessões',
                            border: OutlineInputBorder(),
                            isDense: true),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Campo obrigatório.';
                          final numero = int.tryParse(v);
                          if (numero == null || numero <= 0)
                            return 'Insira um número válido.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: formaPagamentoValue,
                        decoration: const InputDecoration(
                            labelText: 'Forma de Pagamento',
                            border: OutlineInputBorder(),
                            isDense: true),
                        items: ['PIX', 'Dinheiro', 'Convênio']
                            .map((label) =>
                                DropdownMenuItem(value: label, child: Text(label)))
                            .toList(),
                        onChanged: (String? newValue) {
                          setStateInDialog(() {
                            formaPagamentoValue = newValue;
                            convenioController.clear();
                            parcelamentoValue = null;
                          });
                        },
                        validator: (v) =>
                            v == null ? 'Selecione uma forma de pagamento' : null,
                      ),
                      if (formaPagamentoValue == 'Convênio') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: convenioController,
                          decoration: const InputDecoration(
                              labelText: 'Nome do Convênio',
                              border: OutlineInputBorder(),
                              isDense: true),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Nome do convênio é obrigatório'
                              : null,
                        ),
                      ],
                      if (formaPagamentoValue == 'PIX' ||
                          formaPagamentoValue == 'Dinheiro') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: parcelamentoValue,
                          decoration: const InputDecoration(
                              labelText: 'Parcelamento',
                              border: OutlineInputBorder(),
                              isDense: true),
                          items: ['Por Sessão', '3x']
                              .map((label) =>
                                  DropdownMenuItem(value: label, child: Text(label)))
                              .toList(),
                          onChanged: (String? newValue) =>
                              setStateInDialog(() => parcelamentoValue = newValue),
                          validator: (v) =>
                              v == null ? 'Selecione o parcelamento' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ElevatedButton(
                  child: const Text('Agendar'),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      setState(() => _isSaving = true);

                      try {
                        await _firestoreService.agendarSessoesRecorrentes(
                          startDate: _selectedDay!,
                          hora: hora,
                          pacienteId: selectedPacienteId!,
                          pacienteNome: selectedPacienteNome!,
                          quantidade: int.parse(quantidadeSessoesController.text),
                          formaPagamento: formaPagamentoValue,
                          convenio: convenioController.text.isNotEmpty
                              ? convenioController.text
                              : null,
                          parcelamento: parcelamentoValue,
                          statusPagamento: 'Pendente',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Sessões agendadas com sucesso!')));
                        Navigator.of(context).pop(true);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Erro ao agendar: ${e.toString()}')));
                        Navigator.of(context).pop(false);
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  TableCalendar<dynamic> _buildTableCalendar() {
    return TableCalendar(
      locale: 'pt_BR',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      rowHeight: 36.0,
      daysOfWeekHeight: 18.0,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: const TextStyle(fontSize: 15.0),
        headerPadding: const EdgeInsets.symmetric(vertical: 2.0),
        leftChevronPadding: const EdgeInsets.all(4.0),
        rightChevronPadding: const EdgeInsets.all(4.0),
        leftChevronMargin: EdgeInsets.zero,
        rightChevronMargin: EdgeInsets.zero,
      ),
      calendarStyle: const CalendarStyle(
        cellPadding: EdgeInsets.zero,
        cellMargin: EdgeInsets.all(2.0),
      ),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selected, focused) {
        if (!isSameDay(_selectedDay, selected)) {
          setState(() {
            _selectedDay = selected.toUtc();
            _focusedDay = focused.toUtc();
          });
          _loadDataForDay(selected.toUtc());
        }
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay.toUtc();
        _fetchColorsForMonth(focusedDay.toUtc());
      },
      calendarBuilders: CalendarBuilders(defaultBuilder: (context, day, focusedDay) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final color = _dayColors[dateKey];
        return Container(
          margin: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
              child: Text(day.day.toString(),
                  style: const TextStyle(color: Colors.black87, fontSize: 12))),
        );
      }, selectedBuilder: (context, day, focusedDay) {
        return Container(
          margin: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
              child: Text(day.day.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12))),
        );
      }, todayBuilder: (context, day, focusedDay) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final color = _dayColors[dateKey];
        return Container(
          margin: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).primaryColorDark, width: 2)),
          child: Center(
              child: Text(day.day.toString(),
                  style: const TextStyle(color: Colors.black87, fontSize: 12))),
        );
      }),
      calendarFormat: CalendarFormat.month,
    );
  }

  Future<bool?> _showConfirmationDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
  }

  Future<DesmarcarOpcao?> _showDesmarcarOptionsDialog() {
    return showDialog<DesmarcarOpcao>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Opções para Desmarcar'),
          content: const Text('Como você deseja desmarcar?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Apenas esta sessão (repor no final)'),
              onPressed: () => Navigator.of(context).pop(DesmarcarOpcao.apenasEsta),
            ),
            TextButton(
              child: const Text('Esta e as futuras (encerrar)'),
              onPressed: () =>
                  Navigator.of(context).pop(DesmarcarOpcao.estaEFuturas),
            ),
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(DesmarcarOpcao.cancelar),
            ),
          ],
        );
      },
    );
  }

  String _getNomeDiaDaSemana(DateTime data) => DateFormat('EEEE', 'pt_BR')
      .format(data)
      .replaceFirstMapped((RegExp(r'^\w')), (match) => match.group(0)!.toUpperCase());

  Color _getColorForStatus(String status) {
    switch (status) {
      case 'Realizada':
        return Colors.lightBlue.shade100;
      case 'Faltou':
        return Colors.red.shade100;
      case 'Desmarcada':
      case 'Falta Injustificada':
        return Colors.amber.shade100;
      default:
        return Colors.orange.shade100; // Agendada
    }
  }

  String _getDialogTitle(String action) {
    if (action == 'Falta Injustificada') return 'Atenção!';
    return 'Confirmar Ação';
  }

  String _getDialogContent(String action) {
    switch (action) {
      case 'Realizada':
        return 'Deseja marcar esta sessão como "Realizada"?';
      case 'Faltou':
        return 'Deseja marcar esta sessão como "Faltou"?';
      case 'Remarcar':
        return 'Deseja reativar esta sessão? Uma sessão extra será removida do final do bloco para manter a contagem.';
      case 'Falta Injustificada':
        return 'Esta ação irá remarcar esta sessão para o final do pacote e reajustar as sessões futuras.\n\nDeseja continuar?';
      case 'pagar':
        return 'Confirmar o pagamento desta sessão?';
      case 'desfazer_pagamento':
        return 'Deseja desfazer o pagamento desta sessão?';
      case 'desfazer_status':
        return 'Deseja retornar o status para "Agendada"?';
      case 'bloquear':
        return 'Deseja bloquear este horário?';
      case 'desbloquear':
        return 'Deseja desbloquear este horário?';
      default:
        return 'Tem certeza?';
    }
  }
}