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
  
  Future<void> desmarcarSessaoUnica(Horario horario, DateTime dia) async {
    final docId = DateFormat('yyyy-MM-dd').format(dia);
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);

    await ref.update({
      'sessoes.${horario.hora}.status': 'Desmarcada',
      'sessoes.${horario.hora}.desmarcadaEm': Timestamp.now(),
    });
  }

  Future<void> desmarcarSessoesRestantes(Horario horario, DateTime dia) async {
    final WriteBatch batch = _db.batch();
    
    List<DocumentSnapshot> sessoesParaRemover = await _findAllSessionsAfter(horario, dia, includeCurrent: true);

    if (sessoesParaRemover.isEmpty) {
        final docId = DateFormat('yyyy-MM-dd').format(dia);
        final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
        batch.update(ref, {'sessoes.${horario.hora}': FieldValue.delete()});
    } else {
        for (var doc in sessoesParaRemover) {
            batch.update(doc.reference, {'sessoes.${horario.hora}': FieldValue.delete()});
        }
    }

    await batch.commit();
  }


  Future<void> reativarSessao(Horario horario, DateTime diaSelecionado) async {
    final WriteBatch batch = _db.batch();
    final sessaoAtual = horario.sessaoAgendada;
    if (sessaoAtual == null) throw Exception("Sessão inválida para reativação.");
    
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

    // *** LINHA CORRIGIDA ***
    // Se não há uma sessão agendada ou se a sessão não tem um ID de agendamento,
    // significa que é uma sessão única ou um horário vago. Não há sessões "seguintes".
    if (sessaoAgendada == null || sessaoAgendada.agendamentoId.isEmpty) {
      if (includeCurrent && sessaoAgendada != null) {
        final docId = DateFormat('yyyy-MM-dd').format(startDate);
        sessoesEncontradas.add(await _db.collection(_sessoesAgendadasCollection).doc(docId).get());
      }
      return sessoesEncontradas;
    }

    DateTime dataBusca = startDate;
    int iteracoes = 0;
    int maxIteracoes = (sessaoAgendada.totalSessoes) + 52; 

    while(iteracoes < maxIteracoes) { 
      final docId = DateFormat('yyyy-MM-dd').format(dataBusca);
      final doc = await _db.collection(_sessoesAgendadasCollection).doc(docId).get();
      final docData = doc.data() as Map<String, dynamic>?;
      
      if(doc.exists && docData != null) {
          final sessoes = docData['sessoes'] as Map<String, dynamic>?;
          if (sessoes != null && sessoes[horario.hora]?['agendamentoId'] == sessaoAgendada.agendamentoId) {
             if (dataBusca.isAtSameMomentAs(startDate) || dataBusca.isAfter(startDate)) {
                if(dataBusca.isAtSameMomentAs(startDate) && includeCurrent) {
                  sessoesEncontradas.add(doc);
                } else if (dataBusca.isAfter(startDate)) {
                  sessoesEncontradas.add(doc);
                }
             }
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

    // *** LINHA CORRIGIDA ***
    // Fazemos uma checagem segura para garantir que sessaoAgendada e seus campos não são nulos.
    if (sessaoAgendada == null || sessaoAgendada.agendamentoId.isEmpty || sessaoAgendada.agendamentoStartDate == null) {
      throw Exception("Dados do agendamento incompletos para buscar todas as sessões.");
    }
    
    DateTime dataBusca = sessaoAgendada.agendamentoStartDate.toDate();
    int iteracoes = 0;
    int maxIteracoes = (sessaoAgendada.totalSessoes) + 104;
    
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