import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'services/firestore_service.dart';
import 'models/horario_model.dart';

class Sessoes extends StatefulWidget {
  const Sessoes({super.key});

  @override
  State<Sessoes> createState() => _SessoesState();
}

class _SessoesState extends State<Sessoes> {
  final _formKey = GlobalKey<FormState>();
  final _quantidadeSessoesController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<String>> _horariosDisponibilidadePadrao = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Horario> _horariosDoDia = [];
  Map<String, Color> _dayColors = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _horarioEmAgendamento;

  String? _formSelectedPacienteId;
  String? _formSelectedPacienteNome;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initializeData();
  }

  @override
  void dispose() {
    _quantidadeSessoesController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadDataForDay(_selectedDay!);
    await _fetchColorsForMonth(_focusedDay);
  }

  Future<void> _loadDataForDay(DateTime day) async {
    setState(() {
      _isLoading = true;
      _horarioEmAgendamento = null;
    });
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
    setState(() {
      _horarioEmAgendamento = null;
    });
    _fetchColorsForMonth(_focusedDay);
    _loadDataForDay(_selectedDay!);
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

  Future<void> _handleAgendarSessoes(String hora) async {
    if (!(_formKey.currentState?.validate() ?? false) || _formSelectedPacienteId == null) return;
    setState(() => _isSaving = true);
    try {
      await _firestoreService.agendarSessoesRecorrentes(
        startDate: _selectedDay!,
        hora: hora,
        pacienteId: _formSelectedPacienteId!,
        pacienteNome: _formSelectedPacienteNome!,
        quantidade: int.parse(_quantidadeSessoesController.text),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessões agendadas com sucesso!')));
      _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao agendar: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDesmarcarSessao(Horario horario) async {
    final bool? confirmar = await _showConfirmationDialog('Desmarcar Sessão', 'Tem certeza? Esta ação irá reagendar as sessões futuras.');
    if (confirmar != true) return;
    setState(() => _isSaving = true);
    try {
      await _firestoreService.desmarcarSessao(horario, _selectedDay!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão desmarcada e futuras reagendadas!')));
      _reloadDataAfterAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desmarcar: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleReativarSessao(Horario horario) async {
    final bool? confirmar = await _showConfirmationDialog('Reativar Sessão', 'Isso irá reverter o reagendamento e apagar a última sessão extra. Deseja continuar?');
    if (confirmar != true) return;
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

  Future<void> _handleBloquearHorario(String hora) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessões'), centerTitle: true),
      body: Column(
        children: [
          Card(margin: const EdgeInsets.all(8.0), child: _buildTableCalendar()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text("Bloquear todo dia"),
                  onPressed: _isLoading || _isSaving ? null : _handleBloquearDiaInteiro,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text("Desbloquear todo dia"),
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
        if (_horarioEmAgendamento == horario.hora && horario.status == 'disponivel') {
          return Card(elevation: 4, color: Colors.blue.shade50, child: _buildFormularioAgendamento(horario));
        }
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
          TextButton(child: const Text("Agendar"), onPressed: () => setState(() => _horarioEmAgendamento = horario.hora)),
          IconButton(icon: const Icon(Icons.block, color: Colors.grey, size: 20), tooltip: "Bloquear", onPressed: () => _handleBloquearHorario(horario.hora)),
        ];
        break;
      case 'Agendada':
        cardColor = Colors.orange.shade100;
        title = Text(horario.pacienteNome ?? 'Paciente não informado');
        subtitle = Text("Sessão ${horario.sessaoNumero} de ${horario.totalSessoes}");
        actions = [
          TextButton(child: const Text("Desmarcar"), onPressed: () => _handleDesmarcarSessao(horario)),
          IconButton(icon: const Icon(Icons.block, color: Colors.grey, size: 20), tooltip: "Bloquear e reagendar", onPressed: () => _handleDesmarcarSessao(horario)),
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
      child: ListTile(
        leading: Text(horario.hora, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        title: title,
        subtitle: subtitle,
        trailing: _isSaving && _horarioEmAgendamento != horario.hora ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }

  Widget _buildFormularioAgendamento(Horario horario) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Novo Agendamento - ${horario.hora}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getPacientesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Paciente', border: OutlineInputBorder()),
                  items: snapshot.data!.docs.map((doc) => DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(doc['nome']),
                    onTap: () => _formSelectedPacienteNome = doc['nome'],
                  )).toList(),
                  onChanged: (value) => _formSelectedPacienteId = value,
                  validator: (v) => v == null ? 'Selecione um paciente' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantidadeSessoesController,
              decoration: const InputDecoration(labelText: 'Quantidade de Sessões', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Insira um nº válido' : null,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => setState(() => _horarioEmAgendamento = null), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Agendar'),
                  onPressed: _isSaving ? null : () => _handleAgendarSessoes(horario.hora),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  TableCalendar<dynamic> _buildTableCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
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
            margin: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text(day.day.toString(), style: const TextStyle(color: Colors.black87))),
          );
        },
      ),
      calendarFormat: CalendarFormat.month,
      locale: 'pt_BR',
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
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