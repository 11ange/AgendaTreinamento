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
      if (sessaoDataMap != null) {
        final sessaoAgendada = SessaoAgendada.fromMap(sessaoDataMap);
        horariosParaExibir.add(Horario(hora: hora, sessaoAgendada: sessaoAgendada));
      } else {
        horariosParaExibir.add(Horario(hora: hora));
      }
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
    String? formaPagamento,
    String? convenio,
    String? parcelamento,
    String? statusPagamento,
  }) async {
    final agendamentoId = _db.collection(_sessoesAgendadasCollection).doc().id;
    final WriteBatch batch = _db.batch();

    Map<String, dynamic>? pagamentosParcelados;
    if (parcelamento == '3x') {
      pagamentosParcelados = { '1': null, '2': null, '3': null, };
    }

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
        formaPagamento: formaPagamento,
        convenio: convenio,
        parcelamento: parcelamento,
        statusPagamento: statusPagamento,
        dataPagamentoGuia: null,
        pagamentosParcelados: pagamentosParcelados,
        dataPagamentoSessao: null,
      );
      batch.set(docRef, {'sessoes': {hora: novaSessao.toMap()}}, SetOptions(merge: true));
    }
    await batch.commit();
  }
  
  // =======================================================================
  // FUNÇÃO MODIFICADA E CORRIGIDA
  // =======================================================================
  Future<void> desmarcarSessaoUnicaEReagendar(Horario horario, DateTime dia) async {
    final sessaoOriginal = horario.sessaoAgendada;
    if (sessaoOriginal == null) return;

    final writeBatch = _db.batch();
    final horaSessao = horario.hora;

    // 1. Marca a sessão atual como 'Desmarcada'
    final docIdAtual = DateFormat('yyyy-MM-dd').format(dia);
    final refAtual = _db.collection(_sessoesAgendadasCollection).doc(docIdAtual);
    writeBatch.update(refAtual, {
      'sessoes.$horaSessao.status': 'Desmarcada',
      'sessoes.$horaSessao.desmarcadaEm': Timestamp.now(),
    });

    // 2. Encontra todas as sessões do mesmo agendamento para reordenar
    final todasAsSessoesDoAgendamento = await _findAllSessionsInAgendamento(horario);
    
    // Filtra apenas as sessões futuras que estão 'Agendada'
    final sessoesFuturasAgendadas = todasAsSessoesDoAgendamento
        .where((doc) {
          final dataDoc = DateFormat('yyyy-MM-dd').parseUtc(doc.id);
          // Considera apenas as sessões estritamente após a data da sessão desmarcada
          return dataDoc.isAfter(dia) &&
                 (doc.data() as Map<String, dynamic>).containsKey('sessoes') &&
                 ((doc.data() as Map<String, dynamic>)['sessoes'] as Map<String, dynamic>).containsKey(horaSessao) &&
                 (doc.data() as Map<String, dynamic>)['sessoes'][horaSessao]['status'] == 'Agendada';
        })
        .toList();
    
    // 3. Renumera as sessões futuras (n-1)
    for (final doc in sessoesFuturasAgendadas) {
        final sessaoData = (doc.data() as Map<String, dynamic>)['sessoes'][horaSessao];
        final sessao = SessaoAgendada.fromMap(sessaoData);

        if (sessao.sessaoNumero > sessaoOriginal.sessaoNumero) {
            final dadosAtualizados = sessao.toMap();
            dadosAtualizados['sessaoNumero'] = sessao.sessaoNumero - 1;
            writeBatch.update(doc.reference, {'sessoes.$horaSessao': dadosAtualizados});
        }
    }

    // 4. Adiciona uma nova sessão ao final
    if (todasAsSessoesDoAgendamento.isNotEmpty) {
        final ultimaSessaoDoc = todasAsSessoesDoAgendamento.last;
        final ultimaData = DateFormat('yyyy-MM-dd').parseUtc(ultimaSessaoDoc.id);
        final novaDataFinal = ultimaData.add(const Duration(days: 7));
        final novoDocIdFinal = DateFormat('yyyy-MM-dd').format(novaDataFinal);
        final refNovaFinal = _db.collection(_sessoesAgendadasCollection).doc(novoDocIdFinal);
        
        final novaSessaoFinal = SessaoAgendada(
            agendamentoId: sessaoOriginal.agendamentoId,
            agendamentoStartDate: sessaoOriginal.agendamentoStartDate,
            pacienteId: sessaoOriginal.pacienteId,
            pacienteNome: sessaoOriginal.pacienteNome,
            status: 'Agendada',
            sessaoNumero: sessaoOriginal.totalSessoes,
            totalSessoes: sessaoOriginal.totalSessoes,
            formaPagamento: sessaoOriginal.formaPagamento,
            convenio: sessaoOriginal.convenio,
            parcelamento: sessaoOriginal.parcelamento,
            statusPagamento: 'Pendente', // A nova sessão sempre começa como pendente
            pagamentosParcelados: sessaoOriginal.pagamentosParcelados,
        );
        writeBatch.set(refNovaFinal, {'sessoes': {horaSessao: novaSessaoFinal.toMap()}}, SetOptions(merge: true));
    }

    await writeBatch.commit();
  }

  Future<void> desmarcarSessoesRestantes(Horario horario, DateTime dia) async {
    final WriteBatch batch = _db.batch();
    List<DocumentSnapshot> sessoesParaRemover = await _findAllSessionsAfter(horario, dia, includeCurrent: true);
    for (var doc in sessoesParaRemover) {
        batch.update(doc.reference, {'sessoes.${horario.hora}': FieldValue.delete()});
    }
    await batch.commit();
  }

  Future<void> reativarSessao(Horario horario, DateTime diaSelecionado) async {
    final sessaoDesmarcada = horario.sessaoAgendada;
    if(sessaoDesmarcada == null) return;
    
    final WriteBatch batch = _db.batch();
    final horaSessao = horario.hora;

    // 1. Reativa a sessão
    final docIdReativar = DateFormat('yyyy-MM-dd').format(diaSelecionado);
    final refReativar = _db.collection(_sessoesAgendadasCollection).doc(docIdReativar);
    batch.update(refReativar, {
      'sessoes.$horaSessao.status': 'Agendada',
      'sessoes.$horaSessao.desmarcadaEm': FieldValue.delete(),
    });

    // 2. Encontra a última sessão agendada e a remove para manter o total de 10
    final sessoesDoAgendamento = await _findAllSessionsInAgendamento(horario);
    final sessoesAgendadas = sessoesDoAgendamento.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data.containsKey('sessoes') && 
               data['sessoes'].containsKey(horaSessao) &&
               data['sessoes'][horaSessao]['status'] == 'Agendada';
    }).toList();


    if (sessoesAgendadas.isNotEmpty) {
      final ultimaSessaoDoc = sessoesAgendadas.last;
      batch.update(ultimaSessaoDoc.reference, {'sessoes.$horaSessao': FieldValue.delete()});
    }

    await batch.commit();
  }

  Future<void> bloquearHorario(DateTime dia, String hora) async {
    final docId = DateFormat('yyyy-MM-dd').format(dia.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    await ref.set({ 'sessoes': { hora: {'status': 'Bloqueado'} } }, SetOptions(merge: true));
  }
  
  Future<void> bloquearHorariosEmLote(DateTime dia, List<String> horas) async {
    if (horas.isEmpty) return;
    final docId = DateFormat('yyyy-MM-dd').format(dia.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    final WriteBatch batch = _db.batch();
    final Map<String, dynamic> bloqueios = { for (var hora in horas) 'sessoes.$hora': {'status': 'Bloqueado'} };
    batch.update(ref, bloqueios);
    await batch.commit();
  }

  Future<void> desbloquearHorario(DateTime dia, String hora) async {
      final docId = DateFormat('yyyy-MM-dd').format(dia.toUtc());
      final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
      await ref.update({ 'sessoes.$hora': FieldValue.delete() });
  }

  Future<void> desbloquearHorariosEmLote(DateTime dia, List<String> horas) async {
    if (horas.isEmpty) return;
    final docId = DateFormat('yyyy-MM-dd').format(dia.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    final WriteBatch batch = _db.batch();
    final Map<String, dynamic> desbloqueios = { for (var hora in horas) 'sessoes.$hora': FieldValue.delete() };
    batch.update(ref, desbloqueios);
    await batch.commit();
  }
  
  Future<void> _updateAllSessionsInAgendamento(String agendamentoId, Map<String, dynamic> dataToUpdate) async {
    final WriteBatch batch = _db.batch();
    final querySnapshot = await _db.collection(_sessoesAgendadasCollection).get();

    for (var doc in querySnapshot.docs) {
      if (!doc.exists || !doc.data().containsKey('sessoes')) continue;
      final sessoes = doc.data()['sessoes'] as Map<String, dynamic>;
      sessoes.forEach((hora, sessaoData) {
        if (sessaoData['agendamentoId'] == agendamentoId) {
          dataToUpdate.forEach((key, value) {
            batch.update(doc.reference, {'sessoes.$hora.$key': value});
          });
        }
      });
    }
    await batch.commit();
  }
  
  Future<void> _updateSingleSession(String agendamentoId, int sessaoNumero, String hora, Map<String, dynamic> dataToUpdate) async {
    final WriteBatch batch = _db.batch();
    final querySnapshot = await _db.collection(_sessoesAgendadasCollection).get();

    for (var doc in querySnapshot.docs) {
      if (!doc.exists || !doc.data().containsKey('sessoes')) continue;
      
      final sessoes = doc.data()['sessoes'] as Map<String, dynamic>;
      if (sessoes.containsKey(hora) && sessoes[hora]['agendamentoId'] == agendamentoId && sessoes[hora]['sessaoNumero'] == sessaoNumero) {
        dataToUpdate.forEach((key, value) {
          batch.update(doc.reference, {'sessoes.$hora.$key': value});
        });
      }
    }
    await batch.commit();
  }

  Future<void> atualizarPagamentoGuiaConvenio({ required String agendamentoId, required Timestamp dataPagamento}) async {
    await _updateAllSessionsInAgendamento(agendamentoId, { 'dataPagamentoGuia': dataPagamento, 'statusPagamento': 'Recebido', });
  }

  Future<void> cancelarPagamentoGuiaConvenio({ required String agendamentoId }) async {
    await _updateAllSessionsInAgendamento(agendamentoId, { 'dataPagamentoGuia': FieldValue.delete(), 'statusPagamento': 'Pendente', });
  }

  Future<void> atualizarPagamentoParcela({ required String agendamentoId, required int parcela, required Timestamp dataPagamento }) async {
    await _updateAllSessionsInAgendamento(agendamentoId, { 'pagamentosParcelados.$parcela': dataPagamento });
  }

  Future<void> cancelarPagamentoParcela({ required String agendamentoId, required int parcela }) async {
    await _updateAllSessionsInAgendamento(agendamentoId, { 'pagamentosParcelados.$parcela': null });
  }

  Future<void> atualizarPagamentoSessaoUnica({ required SessaoAgendada sessao, required Timestamp dataPagamento, required String hora}) async {
    await _updateSingleSession(sessao.agendamentoId, sessao.sessaoNumero, hora, { 'statusPagamento': 'Pago', 'dataPagamentoSessao': dataPagamento });
  }

  Future<void> cancelarPagamentoSessaoUnica({ required SessaoAgendada sessao, required String hora }) async {
    await _updateSingleSession(sessao.agendamentoId, sessao.sessaoNumero, hora, { 'statusPagamento': 'Pendente', 'dataPagamentoSessao': FieldValue.delete() });
  }

  Future<List<DocumentSnapshot>> _findAllSessionsAfter(Horario horario, DateTime startDate, {bool includeCurrent = false}) async {
    List<DocumentSnapshot> sessoesEncontradas = [];
    final sessaoAgendada = horario.sessaoAgendada;

    if (sessaoAgendada == null || sessaoAgendada.agendamentoId.isEmpty) {
      return sessoesEncontradas;
    }
    
    // As datas no ID do documento estão como YYYY-MM-DD
    final startDateId = DateFormat('yyyy-MM-dd').format(startDate.toUtc());

    final querySnapshot = await _db
        .collection(_sessoesAgendadasCollection)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateId)
        .get();

    for (var doc in querySnapshot.docs) {
        if (!doc.exists || !(doc.data()).containsKey('sessoes')) continue;

        final sessoes = doc.data()['sessoes'] as Map<String, dynamic>;
        if (sessoes.containsKey(horario.hora) && sessoes[horario.hora]['agendamentoId'] == sessaoAgendada.agendamentoId) {
            if (doc.id == startDateId && !includeCurrent) {
                continue;
            }
            sessoesEncontradas.add(doc);
        }
    }
    
    sessoesEncontradas.sort((a,b) => a.id.compareTo(b.id));
    return sessoesEncontradas;
  }

  Future<List<DocumentSnapshot>> _findAllSessionsInAgendamento(Horario horario) async {
    List<DocumentSnapshot> sessoesEncontradas = [];
    final sessaoAgendada = horario.sessaoAgendada;

    if (sessaoAgendada == null || sessaoAgendada.agendamentoId.isEmpty) {
      return sessoesEncontradas;
    }
    
    final querySnapshot = await _db.collection(_sessoesAgendadasCollection).get();
    for (var doc in querySnapshot.docs) {
       if (!doc.exists || !doc.data().containsKey('sessoes')) continue;
      final sessoes = doc.data()['sessoes'] as Map<String, dynamic>;
      sessoes.forEach((hora, sessaoData) {
        if(sessaoData['agendamentoId'] == sessaoAgendada.agendamentoId) {
          if(!sessoesEncontradas.any((d) => d.id == doc.id)) sessoesEncontradas.add(doc);
        }
      });
    }

    sessoesEncontradas.sort((a,b) => a.id.compareTo(b.id));
    return sessoesEncontradas;
  }
}