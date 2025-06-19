import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/horario_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _disponibilidadeCollection = 'disponibilidade';
  static const String _sessoesAgendadasCollection = 'sessoes_agendadas';
  static const String _pacientesCollection = 'pacientes';
  static const String _agendaDocId = 'minha_agenda';

  Future<Map<String, List<String>>> getDisponibilidadePadrao() async {
    try {
      final doc = await _db.collection(_disponibilidadeCollection).doc(_agendaDocId).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, List<String>.from(value)));
      }
      return {};
    } catch (e) {
      print('Erro ao carregar disponibilidade padrão: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getPacientesStream() {
    return _db.collection(_pacientesCollection).orderBy('nome').snapshots();
  }

  Future<DocumentSnapshot> getPacienteById(String pacienteId) {
    return _db.collection(_pacientesCollection).doc(pacienteId).get();
  }

  Future<List<Horario>> getHorariosParaDia(DateTime dia, Map<String, List<String>> disponibilidadePadrao) async {
    List<Horario> horariosParaExibir = [];
    final nomeDiaSemana = DateFormat('EEEE', 'pt_BR').format(dia).replaceFirstMapped((RegExp(r'^\w')), (match) => match.group(0)!.toUpperCase());
    final disponibilidadeBase = disponibilidadePadrao[nomeDiaSemana] ?? [];

    final docId = DateFormat('yyyy-MM-dd').format(dia);
    final doc = await _db.collection(_sessoesAgendadasCollection).doc(docId).get();
    final docData = doc.data() as Map<String, dynamic>?;
    final sessoesDoDia = (doc.exists && docData != null && docData.containsKey('sessoes'))
        ? docData['sessoes'] as Map<String, dynamic>
        : <String, dynamic>{};

    for (String hora in disponibilidadeBase) {
      final sessaoDataMap = sessoesDoDia.containsKey(hora) ? sessoesDoDia[hora] as Map<String, dynamic> : null;
      final sessaoAgendada = sessaoDataMap != null ? SessaoAgendada.fromMap(sessaoDataMap) : null;
      horariosParaExibir.add(Horario(hora: hora, sessaoAgendada: sessaoAgendada));
    }

    horariosParaExibir.sort((a, b) => a.hora.compareTo(b.hora));
    return horariosParaExibir;
  }

  Future<void> agendarSessoesRecorrentes({
    required DateTime startDate,
    required String hora,
    required String pacienteId,
    required String pacienteNome,
    required int quantidade,
  }) async {
    final agendamentoId = _db.collection(_sessoesAgendadasCollection).doc().id;
    final WriteBatch batch = _db.batch();

    for (int i = 0; i < quantidade; i++) {
      final dataSessao = startDate.add(Duration(days: 7 * i));
      final docId = DateFormat('yyyy-MM-dd').format(dataSessao);
      final docRef = _db.collection(_sessoesAgendadasCollection).doc(docId);

      final novaSessao = SessaoAgendada(
        agendamentoId: agendamentoId,
        agendamentoStartDate: Timestamp.fromDate(startDate),
        pacienteId: pacienteId,
        pacienteNome: pacienteNome,
        status: 'Agendada',
        sessaoNumero: i + 1,
        totalSessoes: quantidade,
      );
      batch.set(docRef, {'sessoes': {hora: novaSessao.toMap()}}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> desmarcarSessao(Horario horario, DateTime diaSelecionado) async {
    final WriteBatch batch = _db.batch();
    final sessaoAtual = horario.sessaoAgendada;
    if (sessaoAtual == null) throw Exception("Sessão inválida para desmarcar.");

    List<DocumentSnapshot> sessoesFuturas = await _findAllSessionsAfter(horario, diaSelecionado, includeCurrent: true);
    if (sessoesFuturas.isEmpty) throw Exception("Nenhuma sessão futura encontrada para reagendar.");

    final docIdAtual = DateFormat('yyyy-MM-dd').format(diaSelecionado);
    final refAtual = _db.collection(_sessoesAgendadasCollection).doc(docIdAtual);
    batch.update(refAtual, {
        'sessoes.${horario.hora}.status': 'Desmarcada',
        'sessoes.${horario.hora}.desmarcadaEm': Timestamp.now(),
    });

    for (var doc in sessoesFuturas) {
        if(doc.id == docIdAtual) continue;

        final sessoes = doc.data() as Map<String, dynamic>;
        final sessaoData = sessoes['sessoes'][horario.hora];
        batch.update(doc.reference, {
            'sessoes.${horario.hora}.sessaoNumero': sessaoData['sessaoNumero'] - 1,
            'sessoes.${horario.hora}.reagendada': true,
        });
    }

    final ultimaSessaoDoc = sessoesFuturas.last;
    final dataUltimaSessao = DateFormat('yyyy-MM-dd').parse(ultimaSessaoDoc.id);
    final dataNovaSessao = dataUltimaSessao.add(const Duration(days: 7));
    final docIdNovo = DateFormat('yyyy-MM-dd').format(dataNovaSessao);
    final refNova = _db.collection(_sessoesAgendadasCollection).doc(docIdNovo);

    final novaSessao = SessaoAgendada(
        agendamentoId: sessaoAtual.agendamentoId,
        agendamentoStartDate: sessaoAtual.agendamentoStartDate,
        pacienteId: sessaoAtual.pacienteId,
        pacienteNome: sessaoAtual.pacienteNome,
        status: 'Agendada',
        sessaoNumero: sessaoAtual.totalSessoes,
        totalSessoes: sessaoAtual.totalSessoes,
        reagendada: true,
    );
    batch.set(refNova, {'sessoes': {horario.hora: novaSessao.toMap()}}, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> reativarSessao(Horario horario, DateTime diaSelecionado) async {
    final WriteBatch batch = _db.batch();
    final sessaoAtual = horario.sessaoAgendada;
    if (sessaoAtual == null) throw Exception("Sessão inválida para reativação.");
    
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

    final refAtual = _db.collection(_sessoesAgendadasCollection).doc(DateFormat('yyyy-MM-dd').format(diaSelecionado));
    batch.update(refAtual, {
      'sessoes.${horario.hora}.status': 'Agendada',
      'sessoes.${horario.hora}.desmarcadaEm': FieldValue.delete(),
    });
    
    await batch.commit();
  }

  Future<void> bloquearHorario(DateTime dia, String hora) async {
    final docId = DateFormat('yyyy-MM-dd').format(dia);
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    await ref.set({
      'sessoes': { hora: {'status': 'Bloqueado'} }
    }, SetOptions(merge: true));
  }
  
  Future<void> bloquearHorariosEmLote(DateTime dia, List<String> horas) async {
    if (horas.isEmpty) return;
    final docId = DateFormat('yyyy-MM-dd').format(dia);
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    final WriteBatch batch = _db.batch();

    final Map<String, dynamic> bloqueios = {
      for (var hora in horas) 'sessoes.$hora': {'status': 'Bloqueado'}
    };

    batch.update(ref, bloqueios);
    await batch.commit();
  }

  Future<void> desbloquearHorario(DateTime dia, String hora) async {
      final docId = DateFormat('yyyy-MM-dd').format(dia);
      final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
      await ref.update({ 'sessoes.$hora': FieldValue.delete() });
  }

  Future<void> desbloquearHorariosEmLote(DateTime dia, List<String> horas) async {
    if (horas.isEmpty) return;
    final docId = DateFormat('yyyy-MM-dd').format(dia);
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    final WriteBatch batch = _db.batch();

    final Map<String, dynamic> desbloqueios = {
      for (var hora in horas) 'sessoes.$hora': FieldValue.delete()
    };
    
    batch.update(ref, desbloqueios);
    await batch.commit();
  }

  Future<List<DocumentSnapshot>> _findAllSessionsAfter(Horario horario, DateTime startDate, {bool includeCurrent = false}) async {
    List<DocumentSnapshot> sessoesEncontradas = [];
    final sessaoAgendada = horario.sessaoAgendada;
    if (sessaoAgendada?.agendamentoId == null) throw Exception("Dados do agendamento incompletos.");

    DateTime dataBusca = includeCurrent ? startDate : startDate.add(const Duration(days: 7));
    int iteracoes = 0;
    int maxIteracoes = (sessaoAgendada!.totalSessoes ?? 0) + 52;

    while(iteracoes < maxIteracoes) { 
      final docId = DateFormat('yyyy-MM-dd').format(dataBusca);
      final doc = await _db.collection(_sessoesAgendadasCollection).doc(docId).get();
      final docData = doc.data() as Map<String, dynamic>?;
      
      if(doc.exists && docData != null) {
          final sessoes = docData['sessoes'] as Map<String, dynamic>?;
          if (sessoes != null && sessoes[horario.hora]?['agendamentoId'] == sessaoAgendada.agendamentoId) {
              sessoesEncontradas.add(doc);
          }
      }
      dataBusca = dataBusca.add(const Duration(days: 7));
      iteracoes++;
    }
    sessoesEncontradas.sort((a,b) => a.id.compareTo(b.id));
    return sessoesEncontradas;
  }

  Future<List<DocumentSnapshot>> _findAllSessionsInAgendamento(Horario horario) async {
    List<DocumentSnapshot> sessoesEncontradas = [];
    final sessaoAgendada = horario.sessaoAgendada;
    if (sessaoAgendada?.agendamentoId == null || sessaoAgendada?.agendamentoStartDate == null) {
      throw Exception("Dados do agendamento incompletos para buscar todas as sessões.");
    }
    
    DateTime dataBusca = sessaoAgendada!.agendamentoStartDate.toDate();
    int iteracoes = 0;
    int maxIteracoes = (sessaoAgendada.totalSessoes ?? 0) + 104;
    
    while (iteracoes < maxIteracoes) {
      final docId = DateFormat('yyyy-MM-dd').format(dataBusca);
      final doc = await _db.collection(_sessoesAgendadasCollection).doc(docId).get();
      final docData = doc.data() as Map<String, dynamic>?;

      if (doc.exists && docData != null) {
          final sessoes = docData['sessoes'] as Map<String, dynamic>?;
          if (sessoes != null && sessoes[horario.hora]?['agendamentoId'] == sessaoAgendada.agendamentoId) {
              sessoesEncontradas.add(doc);
          }
      }
      dataBusca = dataBusca.add(const Duration(days: 7));
      iteracoes++;
    }
    return sessoesEncontradas;
  }
}