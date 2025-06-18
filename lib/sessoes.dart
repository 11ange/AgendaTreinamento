import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// --- Modelos de Dados ---
class Horario {
  final String hora;
  final Map<String, dynamic>? sessaoData;

  Horario({required this.hora, this.sessaoData});

  bool get isBooked => sessaoData != null;
  String get status => sessaoData?['status'] ?? 'disponivel';
  String? get agendamentoId => sessaoData?['agendamentoId'];
  String? get pacienteId => sessaoData?['pacienteId'];
  String? get pacienteNome => sessaoData?['pacienteNome'];
  int? get sessaoNumero => sessaoData?['sessaoNumero'];
  int? get totalSessoes => sessaoData?['totalSessoes'];
  bool get reagendada => sessaoData?['reagendada'] ?? false;
  Timestamp? get agendamentoStartDate => sessaoData?['agendamentoStartDate'];
}

// --- Widget Principal ---
class Sessoes extends StatefulWidget {
  const Sessoes({super.key});

  @override
  State<Sessoes> createState() => _SessoesState();
}

class _SessoesState extends State<Sessoes> {
  // --- Constantes e Controladores ---
  final String _disponibilidadeCollectionName = 'disponibilidade';
  final String _sessoesAgendadasCollectionName = 'sessoes_agendadas';
  final String _pacientesCollectionName = 'pacientes';
  final _formKey = GlobalKey<FormState>();
  final _quantidadeSessoesController = TextEditingController();

  // --- Estado do Calendário e Horários ---
  Map<String, List<String>> _horariosDisponibilidadePadrao = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Horario> _horariosParaExibir = [];
  List<Horario> _sessoesDesmarcadasDoDia = [];
  Map<String, Color> _dayColors = {}; // Mapa para as cores do calendário

  // --- Estado da UI e Formulário ---
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedHorario;
  String? _formSelectedPacienteId;
  String? _formSelectedPacienteNome;
  bool _isAgendando = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDataForDay(_selectedDay!);
    _fetchColorsForMonth(_focusedDay);
  }

  @override
  void dispose() {
    _quantidadeSessoesController.dispose();
    super.dispose();
  }

  // --- Funções de Carregamento de Dados ---
  Future<void> _loadDataForDay(DateTime day) async {
    setState(() {
      _isLoading = true;
      _selectedHorario = null;
    });
    await _carregarDisponibilidadePadraoDoFirebase();
    await _atualizarHorariosParaExibir(day);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchColorsForMonth(DateTime month) async {
    await _carregarDisponibilidadePadraoDoFirebase();
    
    Map<String, Color> newColors = {};
    DateTime firstDay = DateTime(month.year, month.month, 1);
    DateTime lastDay = DateTime(month.year, month.month + 1, 0);

    for (var day = firstDay; day.isBefore(lastDay.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final dayOfWeek = _getNomeDiaDaSemana(day);
      final totalSlots = _horariosDisponibilidadePadrao[dayOfWeek]?.length ?? 0;
      
      if (totalSlots == 0) continue;

      try {
        final doc = await FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(dateKey).get();
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
      } catch (e) { print("Erro ao buscar cor para o dia $dateKey: $e");}
    }
    
    if (mounted) {
      setState(() {
        _dayColors = newColors;
      });
    }
  }

  Future<void> _carregarDisponibilidadePadraoDoFirebase() async {
    if (_horariosDisponibilidadePadrao.isNotEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection(_disponibilidadeCollectionName).doc('minha_agenda').get();
      if (doc.exists) {
        _horariosDisponibilidadePadrao = (doc.data() as Map<String, dynamic>).map((key, value) => MapEntry(key, List<String>.from(value)));
      }
    } catch (e) { print('Erro ao carregar disponibilidade: $e'); }
  }

  Future<void> _atualizarHorariosParaExibir(DateTime dia) async {
    _horariosParaExibir.clear();
    _sessoesDesmarcadasDoDia.clear();

    final nomeDiaSemana = _getNomeDiaDaSemana(dia);
    final disponibilidadeBase = _horariosDisponibilidadePadrao[nomeDiaSemana] ?? [];

    try {
      final docId = DateFormat('yyyy-MM-dd').format(dia);
      final doc = await FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(docId).get();
      final docData = doc.data() as Map<String, dynamic>?;
      final sessoesDoDia = (doc.exists && docData != null && docData.containsKey('sessoes')) ? docData['sessoes'] as Map<String, dynamic> : <String, dynamic>{};

      for (String hora in disponibilidadeBase) {
        final sessaoData = sessoesDoDia.containsKey(hora) ? sessoesDoDia[hora] as Map<String, dynamic> : null;
        final horario = Horario(hora: hora, sessaoData: sessaoData);

        if (horario.status == 'Desmarcada') {
          _sessoesDesmarcadasDoDia.add(horario);
        }
        _horariosParaExibir.add(horario);
      }
    } catch (e) { print('Erro ao carregar sessões: $e'); }

    _horariosParaExibir.sort((a, b) => a.hora.compareTo(b.hora));
  }
  
  // --- Lógicas de Agendamento, Bloqueio e Desmarcação ---
  
  // As funções de lógica permanecem as mesmas das versões anteriores.
  // ... (código de _agendarSessoesRecorrentes, _desmarcarSessao, etc, omitido por brevidade, mas incluído no bloco final)

  // --- Widgets de Construção da UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessões'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(child: _buildTableCalendar()),
            const SizedBox(height: 20),
            if (_isLoading) const Center(child: CircularProgressIndicator()) else _buildUIContent(),
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
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
        _loadDataForDay(selected);
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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(day.day.toString(), style: const TextStyle(color: Colors.black87)),
            ),
          );
        },
      ),
      calendarFormat: CalendarFormat.month,
      locale: 'pt_BR',
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
    );
  }

  // --- Restante do código (lógica e widgets) ---
  // O código completo está abaixo para garantir que todas as partes estejam presentes.
  //<editor-fold desc="Funções de Lógica (Agendar, Desmarcar, etc)">
  Future<void> _agendarSessoesRecorrentes() async {
    if (!(_formKey.currentState?.validate() ?? false) || _formSelectedPacienteId == null) return;
    setState(() => _isSaving = true);

    final agendamentoId = FirebaseFirestore.instance.collection("sessoes_agendadas").doc().id;
    final int quantidade = int.parse(_quantidadeSessoesController.text);
    final String hora = _selectedHorario!;
    final DateTime startDate = _selectedDay!;

    try {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < quantidade; i++) {
        final dataSessao = startDate.add(Duration(days: 7 * i));
        final docId = DateFormat('yyyy-MM-dd').format(dataSessao);
        final docRef = FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(docId);

        final novaSessao = {
          'agendamentoId': agendamentoId,
          'agendamentoStartDate': Timestamp.fromDate(startDate),
          'pacienteId': _formSelectedPacienteId!,
          'pacienteNome': _formSelectedPacienteNome!,
          'status': 'Agendada',
          'sessaoNumero': i + 1,
          'totalSessoes': quantidade,
          'reagendada': false,
        };
        batch.set(docRef, {'sessoes': {hora: novaSessao}}, SetOptions(merge: true));
      }
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessões agendadas com sucesso!')));
      _fetchColorsForMonth(_focusedDay); // Atualiza as cores do calendário
      _loadDataForDay(startDate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _desmarcarSessao(Horario horario) async {
    final bool? confirmar = await _showConfirmationDialog('Desmarcar Sessão', 'Tem certeza? Esta ação irá reagendar as sessões futuras.');
    if (confirmar != true) return;

    setState(() => _isSaving = true);

    try {
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        List<DocumentSnapshot> sessoesFuturas = await _findAllSessionsAfter(horario);

        final docIdAtual = DateFormat('yyyy-MM-dd').format(_selectedDay!);
        final refAtual = FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(docIdAtual);
        batch.update(refAtual, {
            'sessoes.${horario.hora}.status': 'Desmarcada', 'sessoes.${horario.hora}.desmarcadaEm': Timestamp.now(),
        });

        for (var doc in sessoesFuturas) {
            final sessoes = doc.data() as Map<String, dynamic>;
            final sessaoData = sessoes['sessoes'][horario.hora];
            batch.update(doc.reference, {
                'sessoes.${horario.hora}.sessaoNumero': sessaoData['sessaoNumero'] - 1,
                'sessoes.${horario.hora}.reagendada': true,
            });
        }

        final ultimaSessaoDoc = sessoesFuturas.isNotEmpty ? sessoesFuturas.last : (await _findAllSessionsInAgendamento(horario, status: 'Agendada')).last;
        final dataUltimaSessao = DateFormat('yyyy-MM-dd').parse(ultimaSessaoDoc.id);
        final dataNovaSessao = dataUltimaSessao.add(const Duration(days: 7));
        final docIdNovo = DateFormat('yyyy-MM-dd').format(dataNovaSessao);
        final refNova = FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(docIdNovo);

        final novaSessao = {
            'agendamentoId': horario.agendamentoId, 'agendamentoStartDate': horario.agendamentoStartDate,
            'pacienteId': horario.pacienteId, 'pacienteNome': horario.pacienteNome,
            'status': 'Agendada', 'sessaoNumero': horario.totalSessoes, 'totalSessoes': horario.totalSessoes, 'reagendada': true,
        };
        batch.set(refNova, {'sessoes': {horario.hora: novaSessao}}, SetOptions(merge: true));

        await batch.commit();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão desmarcada e futuras reagendadas!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desmarcar: ${e.toString()}')));
    } finally {
      _fetchColorsForMonth(_focusedDay);
      _loadDataForDay(_selectedDay!);
      setState(() => _isSaving = false);
    }
  }

  Future<void> _reativarSessao(Horario horario) async {
    final bool? confirmar = await _showConfirmationDialog('Reativar Sessão', 'Isso irá reverter o reagendamento. Deseja continuar?');
    if (confirmar != true) return;

    setState(() => _isSaving = true);
    try {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final List<DocumentSnapshot> todasSessoes = await _findAllSessionsInAgendamento(horario);
      if (todasSessoes.isEmpty) throw Exception("Nenhuma sessão encontrada para reativar.");
      
      todasSessoes.sort((a, b) => a.id.compareTo(b.id));
      
      final ultimaSessaoDoc = todasSessoes.last;
      batch.update(ultimaSessaoDoc.reference, {'sessoes.${horario.hora}': FieldValue.delete()});

      for (final doc in todasSessoes) {
        if (doc.id == ultimaSessaoDoc.id) continue;

        final docData = doc.data() as Map<String, dynamic>?;
        if (docData == null || !docData.containsKey('sessoes')) continue;
        
        final sessoes = docData['sessoes'] as Map<String, dynamic>?;
        if (sessoes == null || !sessoes.containsKey(horario.hora)) continue;

        final sessaoData = sessoes[horario.hora] as Map<String, dynamic>;
        final bool foiReagendada = sessaoData['reagendada'] ?? false;
        
        if (foiReagendada) {
            batch.update(doc.reference, {
                'sessoes.${horario.hora}.sessaoNumero': FieldValue.increment(1),
                'sessoes.${horario.hora}.reagendada': false,
            });
        }
      }

      final refAtual = FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(DateFormat('yyyy-MM-dd').format(_selectedDay!));
      batch.update(refAtual, {
        'sessoes.${horario.hora}.status': 'Agendada',
        'sessoes.${horario.hora}.desmarcadaEm': FieldValue.delete(),
      });
      
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão reativada com sucesso!')));

    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao reativar: ${e.toString()}')));
    } finally {
      _fetchColorsForMonth(_focusedDay);
      _loadDataForDay(_selectedDay!);
      setState(() => _isSaving = false);
    }
  }
  
  Future<void> _bloquearHorario(String hora) async {
    final docId = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final ref = FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(docId);
    try {
      await ref.set({
        'sessoes': { hora: {'status': 'Bloqueado'} }
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horário bloqueado!')));
      _fetchColorsForMonth(_focusedDay);
      _loadDataForDay(_selectedDay!);
    } catch (e) { print(e); }
  }

  Future<void> _desbloquearHorario(String hora) async {
      final docId = DateFormat('yyyy-MM-dd').format(_selectedDay!);
      final ref = FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(docId);
      try {
        await ref.update({ 'sessoes.$hora': FieldValue.delete() });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horário desbloqueado!')));
        _fetchColorsForMonth(_focusedDay);
        _loadDataForDay(_selectedDay!);
      } catch (e) { print(e); }
  }

  Future<void> _desmarcarTodasSeguintes(Horario horario) async {
    final bool? confirmar = await _showConfirmationDialog('Desmarcar Todas', 'Isso irá desmarcar esta sessão e TODAS as futuras. Deseja continuar?');
    if (confirmar != true) return;

    setState(() => _isSaving = true);
    try {
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        List<DocumentSnapshot> sessoesParaRemover = await _findAllSessionsAfter(horario, includeCurrent: true);
        for(var doc in sessoesParaRemover) {
            batch.update(doc.reference, {'sessoes.${horario.hora}': FieldValue.delete()});
        }
        await batch.commit();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessões desmarcadas com sucesso.')));
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desmarcar todas: ${e.toString()}')));
    } finally {
      _fetchColorsForMonth(_focusedDay);
      _loadDataForDay(_selectedDay!);
      setState(() => _isSaving = false);
    }
  }
  
  Future<List<DocumentSnapshot>> _findAllSessionsInAgendamento(Horario horario, {String? status}) async {
    List<DocumentSnapshot> sessoesEncontradas = [];
    if (horario.agendamentoId == null || horario.agendamentoStartDate == null) throw Exception("Dados do agendamento incompletos.");
    
    DateTime dataBusca = horario.agendamentoStartDate!.toDate();
    int iteracoes = 0;
    int maxIteracoes = (horario.totalSessoes ?? 0) + 15;
    
    while (iteracoes < maxIteracoes) {
      final docId = DateFormat('yyyy-MM-dd').format(dataBusca);
      final doc = await FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(docId).get();
      final docData = doc.data() as Map<String, dynamic>?;

      if (doc.exists && docData != null) {
          final sessoes = docData['sessoes'] as Map<String, dynamic>?;
          if (sessoes != null && sessoes[horario.hora]?['agendamentoId'] == horario.agendamentoId) {
              if(status == null || sessoes[horario.hora]?['status'] == status) {
                  sessoesEncontradas.add(doc);
              }
          }
      }
      dataBusca = dataBusca.add(const Duration(days: 7));
      iteracoes++;
    }
    sessoesEncontradas.sort((a,b) => a.id.compareTo(b.id));
    return sessoesEncontradas;
  }

  Future<List<DocumentSnapshot>> _findAllSessionsAfter(Horario horario, {bool includeCurrent = false}) async {
    List<DocumentSnapshot> sessoesEncontradas = [];
    if (horario.agendamentoId == null) throw Exception("Dados do agendamento incompletos.");
    
    DateTime dataBusca = includeCurrent ? _selectedDay! : _selectedDay!.add(const Duration(days: 7));
    int iteracoes = 0;
    int maxIteracoes = (horario.totalSessoes ?? 0) * 2;
    
    while(iteracoes < maxIteracoes) { 
      final docId = DateFormat('yyyy-MM-dd').format(dataBusca);
      final doc = await FirebaseFirestore.instance.collection(_sessoesAgendadasCollectionName).doc(docId).get();
      final docData = doc.data() as Map<String, dynamic>?;
      
      if(doc.exists && docData != null) {
          final sessoes = docData['sessoes'] as Map<String, dynamic>?;
          if (sessoes != null && sessoes[horario.hora]?['agendamentoId'] == horario.agendamentoId) {
              sessoesEncontradas.add(doc);
          }
      }
      dataBusca = dataBusca.add(const Duration(days: 7));
      iteracoes++;
    }
    sessoesEncontradas.sort((a,b) => a.id.compareTo(b.id));
    return sessoesEncontradas;
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

  void _handleHorarioTap(Horario horario) {
    setState(() {
      if (_selectedHorario == horario.hora) {
        _selectedHorario = null;
        _isAgendando = false;
      } else {
        _selectedHorario = horario.hora;
        _isAgendando = false;
      }
    });
  }

  String _getNomeDiaDaSemana(DateTime data) => DateFormat('EEEE', 'pt_BR').format(data).replaceFirstMapped((RegExp(r'^\w')), (match) => match.group(0)!.toUpperCase());
  
  Widget _buildUIContent() {
    return Column(
      children: [
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: _horariosParaExibir.map((horario) {
            final isSelected = _selectedHorario == horario.hora;
            Color color;
            String text = horario.hora;
            Color textColor = Colors.white;

            switch(horario.status) {
              case 'Agendada':
                color = Colors.orange;
                text = '${horario.hora}\n${horario.pacienteNome ?? ""}';
                break;
              case 'Desmarcada':
                color = Colors.yellow.shade700;
                text = '${horario.hora}\n${horario.pacienteNome ?? ""}';
                textColor = Colors.black;
                break;
              case 'Bloqueado':
                color = Colors.grey.shade600;
                text = '${horario.hora}\n(Bloqueado)';
                break;
              default: color = Colors.green;
            }
            return ElevatedButton(
              onPressed: () => _handleHorarioTap(horario),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSelected ? Colors.blue.shade700 : Colors.transparent, width: 3),
                ),
              ),
              child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: textColor)),
            );
          }).toList(),
        ),
        _buildDetalhesContainer(),
        _buildSessoesDesmarcadasContainer(),
      ],
    );
  }

  Widget _buildDetalhesContainer() {
    if (_selectedHorario == null) return const SizedBox.shrink();
    final horario = _horariosParaExibir.firstWhere((h) => h.hora == _selectedHorario);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSaving ? const Center(child: CircularProgressIndicator()) : _buildDetalheConteudo(horario),
      ),
    );
  }

  Widget _buildDetalheConteudo(Horario horario) {
    switch (horario.status) {
      case 'Agendada': return _buildDetalhesAgendamento(horario);
      case 'Bloqueado': return _buildDetalhesBloqueado(horario);
      case 'disponivel':
        return _isAgendando ? _buildFormularioAgendamento(horario) : _buildOpcoesDisponivel(horario);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildSessoesDesmarcadasContainer() {
      if(_sessoesDesmarcadasDoDia.isEmpty) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sessões Desmarcadas neste Dia", style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ..._sessoesDesmarcadasDoDia.map((horario) => ListTile(
                title: Text("${horario.hora} - ${horario.pacienteNome}"),
                subtitle: Text("Desmarcada em ${DateFormat('dd/MM/yyyy').format((horario.sessaoData!['desmarcadaEm'] as Timestamp).toDate())}"),
                trailing: TextButton( child: const Text("Reativar"), onPressed: () => _reativarSessao(horario) ),
            )).toList(),
          ],
        ),
      );
  }

  Widget _buildDetalhesAgendamento(Horario horario) {
    return Column(
      key: ValueKey('detalhes_${horario.hora}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Agendamento - ${horario.hora}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection(_pacientesCollectionName).doc(horario.pacienteId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text("Carregando dados do paciente...");
            final pacienteData = snapshot.data!.data() as Map<String, dynamic>;
            return Text('Contato: ${pacienteData['telefoneResponsavel'] ?? 'Não informado'}');
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Sessão: ${horario.sessaoNumero} de ${horario.totalSessoes}'),
            if (horario.reagendada)
              const Text(' - Reagendada', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.deepPurple))
          ],
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.event_busy),
                  label: const Text('Desmarcar Sessão'),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                  onPressed: () => _desmarcarSessao(horario),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Desmarcar Todas'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _desmarcarTodasSeguintes(horario),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.block, color: Colors.black,),
              label: const Text('Bloquear e Reagendar', style: TextStyle(color: Colors.black)),
              onPressed: () => _desmarcarSessao(horario),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetalhesBloqueado(Horario horario) {
    return Column(
      key: ValueKey('bloqueado_${horario.hora}'),
      children: [
        Text('Horário Bloqueado', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        const Text('Este horário não está disponível para agendamentos.'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.lock_open),
          label: const Text('Desbloquear Horário'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () => _desbloquearHorario(horario.hora),
        )
      ],
    );
  }

  Widget _buildOpcoesDisponivel(Horario horario) {
    return Column(
      key: ValueKey('opcoes_${horario.hora}'),
      children: [
        Text('Horário Disponível - ${horario.hora}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Agendar Paciente'),
          onPressed: () => setState(() => _isAgendando = true),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.block),
          label: const Text('Bloquear este Horário'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
          onPressed: () => _bloquearHorario(horario.hora),
        ),
      ],
    );
  }

  Widget _buildFormularioAgendamento(Horario horario) {
    return Form(
      key: _formKey,
      child: Column(
        key: ValueKey('form_${horario.hora}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Novo Agendamento - ${horario.hora}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection(_pacientesCollectionName).orderBy('nome').get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Text("Carregando pacientes...");
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
              TextButton(onPressed: () => setState(() => _isAgendando = false), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Agendar'),
                onPressed: _agendarSessoesRecorrentes,
              ),
            ],
          )
        ],
      ),
    );
  }
  //</editor-fold>
}