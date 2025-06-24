// File: lib/sessoes.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'services/firestore_service.dart';
import 'models/horario_model.dart';

enum DesmarcarOpcao { apenasEsta, todasAsFuturas, cancelar }

class Sessoes extends StatefulWidget {
  const Sessoes({super.key});

  @override
  State<Sessoes> createState() => _SessoesState();
}

class _SessoesState extends State<Sessoes> {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<String>> _horariosDisponibilidadePadrao = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Horario> _horariosDoDia = [];
  Map<String, Color> _dayColors = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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
        _horariosDisponibilidadePadrao = await _firestoreService.getDisponibilidadePadrao();
      }
      _horariosDoDia = await _firestoreService.getHorariosParaDia(day, _horariosDisponibilidadePadrao);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao carregar dados: $e")));
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchColorsForMonth(DateTime month) async {
    if (_horariosDisponibilidadePadrao.isEmpty) {
      _horariosDisponibilidadePadrao = await _firestoreService.getDisponibilidadePadrao();
    }
    Map<String, Color> newColors = {};
    DateTime firstDay = DateTime(month.year, month.month, 1);
    DateTime lastDay = DateTime(month.year, month.month + 1, 0);

    for (var day = firstDay; day.isBefore(lastDay.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final dayOfWeek = _getNomeDiaDaSemana(day);
      final totalSlots = _horariosDisponibilidadePadrao[dayOfWeek]?.length ?? 0;
      if (totalSlots == 0) continue;
      try {
        final doc = await FirebaseFirestore.instance.collection('sessoes_agendadas').doc(dateKey).get();
        final docData = doc.data() as Map<String, dynamic>?;
        final sessoesDoDia = (doc.exists && docData != null && docData.containsKey('sessoes')) ? docData['sessoes'] as Map<String, dynamic> : <String, dynamic>{};
        int bookedCount = sessoesDoDia.values.where((s) => s['status'] == 'Agendada' || s['status'] == 'Bloqueado').length;
        if (bookedCount >= totalSlots) {
          newColors[dateKey] = Colors.red.shade300;
        } else if (bookedCount > 0) {
          newColors[dateKey] = Colors.yellow.shade400;
        } else {
          newColors[dateKey] = Colors.green.shade300;
        }
      } catch (e) { print("Erro ao buscar cor para o dia $dateKey: $e"); }
    }
    if (mounted) {
      setState(() => _dayColors = newColors);
    }
  }

  void _reloadDataAfterAction() {
    _fetchColorsForMonth(_focusedDay);
    _loadDataForDay(_selectedDay!);
  }

  Future<void> _handleDesmarcarSessao(Horario horario) async {
    final opcao = await _showDesmarcarOptionsDialog();
    if (opcao == null || opcao == DesmarcarOpcao.cancelar) return;

    setState(() => _isSaving = true);
    try {
      switch (opcao) {
        case DesmarcarOpcao.apenasEsta:
          await _firestoreService.desmarcarSessaoUnica(horario, _selectedDay!);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão desmarcada com sucesso!')));
          break;
        case DesmarcarOpcao.todasAsFuturas:
          await _firestoreService.desmarcarSessoesRestantes(horario, _selectedDay!);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão atual e futuras foram removidas!')));
          break;
        case DesmarcarOpcao.cancelar:
          break;
      }
      _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desmarcar: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleBloquearHorario(String hora, {bool desmarcando = false}) async {
    if (desmarcando) {
        final confirmar = await _showConfirmationDialog("Bloquear e Desmarcar?", "Esta ação irá desmarcar a sessão e bloquear o horário. Deseja continuar?");
        if (confirmar != true) return;
    }
    setState(() => _isSaving = true);
    try {
      await _firestoreService.bloquearHorario(_selectedDay!, hora);
      _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao bloquear: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  Future<void> _handleDesbloquearHorario(String hora) async {
    setState(() => _isSaving = true);
    try {
      await _firestoreService.desbloquearHorario(_selectedDay!, hora);
      _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desbloquear: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleReativarSessao(Horario horario) async {
    setState(() => _isSaving = true);
    try {
      await _firestoreService.reativarSessao(horario, _selectedDay!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão reativada com sucesso!')));
      _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao reativar: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleBloquearDiaInteiro() async {
    final confirmar = await _showConfirmationDialog("Bloquear Dia", "Tem certeza que deseja bloquear todos os horários disponíveis de hoje?");
    if (confirmar != true) return;
    setState(() => _isSaving = true);
    try {
      final horariosParaBloquear = _horariosDoDia.where((h) => h.status == 'disponivel').map((h) => h.hora).toList();
      if (horariosParaBloquear.isNotEmpty) {
        await _firestoreService.bloquearHorariosEmLote(_selectedDay!, horariosParaBloquear);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horários disponíveis bloqueados!')));
      _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao bloquear horários: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDesbloquearDiaInteiro() async {
    final confirmar = await _showConfirmationDialog("Desbloquear Dia", "Tem certeza que deseja desbloquear todos os horários bloqueados de hoje?");
    if (confirmar != true) return;
    setState(() => _isSaving = true);
    try {
      final horariosParaDesbloquear = _horariosDoDia.where((h) => h.status == 'Bloqueado').map((h) => h.hora).toList();
      if (horariosParaDesbloquear.isNotEmpty) {
        await _firestoreService.desbloquearHorariosEmLote(_selectedDay!, horariosParaDesbloquear);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horários bloqueados removidos!')));
      _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desbloquear horários: ${e.toString()}')));
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
          Card(
            margin: const EdgeInsets.all(8.0),
            child: _buildTableCalendar()
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(child: ElevatedButton(
                  child: const FittedBox(child: Text("Bloquear todo dia")),
                  onPressed: _isLoading || _isSaving ? null : _handleBloquearDiaInteiro,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  child: const FittedBox(child: Text("Desbloquear todo dia")),
                  onPressed: _isLoading || _isSaving ? null : _handleDesbloquearDiaInteiro,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
                )),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildHorariosList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHorariosList() {
    if (_horariosDoDia.isEmpty) {
      return const Center(child: Text("Nenhum horário de trabalho definido para este dia."));
    }
    List<Horario> renderList = [];
    for (var horario in _horariosDoDia) {
      if (horario.status == 'Desmarcada') {
        renderList.add(Horario(hora: horario.hora, sessaoAgendada: null));
        renderList.add(horario);
      } else {
        renderList.add(horario);
      }
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: renderList.length,
      itemBuilder: (context, index) {
        final horario = renderList[index];
        return _buildHorarioListItem(horario);
      },
    );
  }

  Widget _buildHorarioListItem(Horario horario) {
    Color cardColor = Colors.white;
    Widget title = const Text("");
    Widget? subtitle;
    List<Widget> actions = [];

    switch (horario.status) {
      case 'disponivel':
        cardColor = Colors.green.shade100;
        title = const Text("Horário Disponível", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
        actions = [
          TextButton(child: const Text("Agendar"), onPressed: () => _showAgendamentoPopup(context, horario.hora)),
          IconButton(icon: const Icon(Icons.block, color: Colors.grey, size: 20), tooltip: "Bloquear", onPressed: () => _handleBloquearHorario(horario.hora)),
        ];
        break;
      case 'Agendada':
        cardColor = Colors.orange.shade100;
        title = Text(horario.pacienteNome ?? 'Paciente não informado');
        subtitle = Text(
          "Sessão ${horario.sessaoNumero} de ${horario.totalSessoes}",
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );
        actions = [
          TextButton(child: const Text("Desmarcar"), onPressed: () => _handleDesmarcarSessao(horario)),
          IconButton(icon: const Icon(Icons.block, color: Colors.grey, size: 20), tooltip: "Bloquear e Desmarcar", onPressed: () => _handleBloquearHorario(horario.hora, desmarcando: true)),
        ];
        break;
      case 'Desmarcada':
        cardColor = Colors.yellow.shade200;
        title = Text(horario.pacienteNome ?? 'Paciente não informado', style: const TextStyle(decoration: TextDecoration.lineThrough));
        subtitle = Text("Desmarcado em: ${DateFormat('dd/MM/yy').format(horario.desmarcadaEm!.toDate())}");
        actions = [
          TextButton(child: const Text("Reativar"), onPressed: () => _handleReativarSessao(horario)),
        ];
        break;
      case 'Bloqueado':
        cardColor = Colors.grey.shade300;
        title = const Text("Horário Bloqueado", style: TextStyle(fontStyle: FontStyle.italic));
        actions = [
          IconButton(icon: const Icon(Icons.lock_open, color: Colors.green, size: 20), tooltip: "Desbloquear", onPressed: () => _handleDesbloquearHorario(horario.hora)),
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
            Text(horario.hora, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) subtitle,
                ],
              ),
            ),
            if (_isSaving)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
            else
                Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
      ),
    );
  }

  Future<void> _showAgendamentoPopup(BuildContext context, String hora) {
    final formKey = GlobalKey<FormState>();
    final quantidadeSessoesController = TextEditingController(text: '1');
    final convenioController = TextEditingController();

    String? selectedPacienteId;
    String? selectedPacienteNome;
    String? formaPagamentoValue;
    String? parcelamentoValue;

    return showDialog(
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
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestoreService.getPacientesStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          return DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Paciente', border: OutlineInputBorder(), isDense: true),
                            items: snapshot.data!.docs.map((doc) => DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(doc['nome']),
                              onTap: () => selectedPacienteNome = doc['nome'],
                            )).toList(),
                            onChanged: (value) => selectedPacienteId = value,
                            validator: (v) => v == null ? 'Selecione um paciente' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: quantidadeSessoesController,
                        decoration: const InputDecoration(labelText: 'Quantidade de Sessões', border: OutlineInputBorder(), isDense: true),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Campo obrigatório.';
                          final numero = int.tryParse(v);
                          if (numero == null || numero <= 0) return 'Insira um número válido.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // -- ALTERAÇÃO AQUI --
                      DropdownButtonFormField<String>(
                        value: formaPagamentoValue,
                        decoration: const InputDecoration(labelText: 'Forma de Pagamento', border: OutlineInputBorder(), isDense: true),
                        items: ['PIX', 'Dinheiro', 'Convênio']
                            .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                            .toList(),
                        onChanged: (String? newValue) {
                          setStateInDialog(() {
                            formaPagamentoValue = newValue;
                            convenioController.clear();
                            parcelamentoValue = null;
                          });
                        },
                        validator: (v) => v == null ? 'Selecione uma forma de pagamento' : null,
                      ),
                      // -- ALTERAÇÃO AQUI --
                      if (formaPagamentoValue == 'Convênio') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: convenioController,
                          decoration: const InputDecoration(labelText: 'Nome do Convênio', border: OutlineInputBorder(), isDense: true),
                          validator: (v) => (v == null || v.isEmpty) ? 'Nome do convênio é obrigatório' : null,
                        ),
                      ],
                      // -- ALTERAÇÃO AQUI --
                      if (formaPagamentoValue == 'PIX' || formaPagamentoValue == 'Dinheiro') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: parcelamentoValue,
                          decoration: const InputDecoration(labelText: 'Parcelamento', border: OutlineInputBorder(), isDense: true),
                          items: ['Por Sessão', '3x']
                              .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                              .toList(),
                          onChanged: (String? newValue) => setStateInDialog(() => parcelamentoValue = newValue),
                          validator: (v) => v == null ? 'Selecione o parcelamento' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Agendar'),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      setState(() => _isSaving = true);
                      Navigator.of(context).pop(); // Fecha o popup antes de salvar
                      try {
                        await _firestoreService.agendarSessoesRecorrentes(
                          startDate: _selectedDay!,
                          hora: hora,
                          pacienteId: selectedPacienteId!,
                          pacienteNome: selectedPacienteNome!,
                          quantidade: int.parse(quantidadeSessoesController.text),
                          formaPagamento: formaPagamentoValue,
                          convenio: convenioController.text.isNotEmpty ? convenioController.text : null,
                          parcelamento: parcelamentoValue,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessões agendadas com sucesso!')));
                        _reloadDataAfterAction();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao agendar: ${e.toString()}')));
                      } finally {
                        if(mounted) setState(() => _isSaving = false);
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
            _selectedDay = selected;
            _focusedDay = focused;
          });
          _loadDataForDay(selected);
        }
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
        _fetchColorsForMonth(focusedDay);
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final dateKey = DateFormat('yyyy-MM-dd').format(day);
          final color = _dayColors[dateKey];
          return Container(
            margin: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text(day.day.toString(), style: const TextStyle(color: Colors.black87, fontSize: 12))),
          );
        },
        selectedBuilder: (context, day, focusedDay) {
           return Container(
            margin: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(day.day.toString(), style: const TextStyle(color: Colors.white, fontSize: 12))),
          );
        },
        todayBuilder: (context, day, focusedDay) {
          final dateKey = DateFormat('yyyy-MM-dd').format(day);
          final color = _dayColors[dateKey];
          return Container(
            margin: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).primaryColorDark, width: 2)
            ),
            child: Center(child: Text(day.day.toString(), style: const TextStyle(color: Colors.black87, fontSize: 12))),
          );
        }
      ),
      calendarFormat: CalendarFormat.month,
      locale: 'pt_BR',
    );
  }

  Future<DesmarcarOpcao?> _showDesmarcarOptionsDialog() {
    return showDialog<DesmarcarOpcao>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Escolha uma opção'),
          content: const Text('Como você deseja desmarcar esta sessão?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Apenas esta sessão'),
              onPressed: () => Navigator.of(context).pop(DesmarcarOpcao.apenasEsta),
            ),
            TextButton(
              child: const Text('Esta e as futuras'),
              onPressed: () => Navigator.of(context).pop(DesmarcarOpcao.todasAsFuturas),
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

  Future<bool?> _showConfirmationDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sim')),
        ],
      ),
    );
  }
  
  String _getNomeDiaDaSemana(DateTime data) => DateFormat('EEEE', 'pt_BR').format(data).replaceFirstMapped((RegExp(r'^\w')), (match) => match.group(0)!.toUpperCase());
}