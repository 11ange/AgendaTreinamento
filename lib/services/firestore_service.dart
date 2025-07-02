import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/horario_model.dart';
import '../controle_pagamentos.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _disponibilidadeCollection = 'disponibilidade';
  static const String _sessoesAgendadasCollection = 'sessoes_agendadas';
  static const String _pacientesCollection = 'pacientes';
  static const String _agendaDocId = 'minha_agenda';

  Future<Map<String, List<String>>> getDisponibilidadePadrao() async {
    try {
      final doc =
          await _db.collection(_disponibilidadeCollection).doc(_agendaDocId).get();
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

  Future<List<QueryDocumentSnapshot>> getPacientesSemAgendamentoAtivo() async {
    final Set<String> pacientesComAgendamento = {};
    final sessoesSnapshot = await _db
        .collection(_sessoesAgendadasCollection)
        .where('sessoes', isNotEqualTo: {})
        .get();

    for (var doc in sessoesSnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('sessoes')) {
        final sessoes = data['sessoes'] as Map<String, dynamic>;
        for (var sessaoData in sessoes.values) {
          if (sessaoData['status'] == 'Agendada' || sessaoData['status'] == 'Realizada' || sessaoData['status'] == 'Faltou' || sessaoData['status'] == 'Falta Injustificada') {
            pacientesComAgendamento.add(sessaoData['pacienteId']);
          }
        }
      }
    }

    final pacientesSnapshot = await _db.collection(_pacientesCollection).orderBy('nome').get();
    final pacientesDisponiveis = pacientesSnapshot.docs.where((doc) {
      return !pacientesComAgendamento.contains(doc.id);
    }).toList();
    
    return pacientesDisponiveis;
  }

  Future<List<Horario>> getHorariosParaDia(
      DateTime dia, Map<String, List<String>> disponibilidadePadrao) async {
    List<Horario> horariosParaExibir = [];
    final nomeDiaSemana = DateFormat('EEEE', 'pt_BR')
        .format(dia)
        .replaceFirstMapped((RegExp(r'^\w')), (match) => match.group(0)!.toUpperCase());
    final disponibilidadeBase = disponibilidadePadrao[nomeDiaSemana] ?? [];

    final docId = DateFormat('yyyy-MM-dd').format(dia);
    final doc =
        await _db.collection(_sessoesAgendadasCollection).doc(docId).get();
    final docData = doc.data() as Map<String, dynamic>?;
    final sessoesDoDia =
        (doc.exists && docData != null && docData.containsKey('sessoes'))
            ? docData['sessoes'] as Map<String, dynamic>
            : <String, dynamic>{};

    for (String hora in disponibilidadeBase) {
      final sessaoDataMap = sessoesDoDia.containsKey(hora)
          ? sessoesDoDia[hora] as Map<String, dynamic>
          : null;
      if (sessaoDataMap != null) {
        final sessaoAgendada = SessaoAgendada.fromMap(sessaoDataMap);
        horariosParaExibir
            .add(Horario(hora: hora, sessaoAgendada: sessaoAgendada));
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
    final writeBatch = _db.batch();

    int sessoesCriadas = 0;
    DateTime dataAtual = startDate;

    while (sessoesCriadas < quantidade) {
      if (dataAtual.weekday == DateTime.saturday ||
          dataAtual.weekday == DateTime.sunday) {
        dataAtual = dataAtual.add(const Duration(days: 1));
        continue;
      }

      final docId = DateFormat('yyyy-MM-dd').format(dataAtual);
      final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
      final docSnapshot = await ref.get();

      bool horarioOcupado = false;
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('sessoes') && data['sessoes'].containsKey(hora)) {
          horarioOcupado = true;
        }
      }

      if (!horarioOcupado) {
        sessoesCriadas++;
        Map<String, dynamic>? pagamentosParcelados;
        if (parcelamento == '3x') {
          pagamentosParcelados = {'1': null, '2': null, '3': null};
        }
        final novaSessao = SessaoAgendada(
          agendamentoId: agendamentoId,
          agendamentoStartDate: Timestamp.fromDate(startDate),
          pacienteId: pacienteId,
          pacienteNome: pacienteNome,
          status: 'Agendada',
          sessaoNumero: sessoesCriadas,
          totalSessoes: quantidade,
          formaPagamento: formaPagamento,
          convenio: convenio,
          parcelamento: parcelamento,
          statusPagamento: statusPagamento ?? 'Pendente',
          pagamentosParcelados: pagamentosParcelados,
        );
        writeBatch.set(
            ref, {'sessoes': {hora: novaSessao.toMap()}}, SetOptions(merge: true));
      }

      dataAtual = dataAtual.add(const Duration(days: 7));

      if (dataAtual.isAfter(startDate.add(const Duration(days: 365 * 2)))) {
        throw Exception(
            "Não foi possível encontrar horários livres para todas as sessões.");
      }
    }

    await writeBatch.commit();
  }

  Future<void> updateStatusSessao(
      {required DateTime data,
      required String hora,
      required String novoStatus}) async {
    final docId = DateFormat('yyyy-MM-dd').format(data.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    await ref.update({'sessoes.$hora.status': novoStatus});
  }

  Future<void> updatePagamentoSessao(
      {required DateTime data, required String hora, required bool pago}) async {
    final docId = DateFormat('yyyy-MM-dd').format(data.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    await ref.update({
      'sessoes.$hora.statusPagamento': pago ? 'Pago' : 'Pendente',
      'sessoes.$hora.dataPagamentoSessao':
          pago ? Timestamp.now() : FieldValue.delete(),
    });
  }

  Future<void> registrarFaltaInjustificada(
      {required DateTime dataSessaoFaltou, required String hora}) async {
    final writeBatch = _db.batch();
    final docIdFaltou = DateFormat('yyyy-MM-dd').format(dataSessaoFaltou.toUtc());
    final refFaltou = _db.collection(_sessoesAgendadasCollection).doc(docIdFaltou);

    final docFaltouSnapshot = await refFaltou.get();
    final docFaltouData = docFaltouSnapshot.data() as Map<String, dynamic>?;

    if (docFaltouData == null || docFaltouData['sessoes']?[hora] == null) {
      throw Exception("Sessão a ser desmarcada não encontrada.");
    }
    final sessaoFaltouData = docFaltouData['sessoes'][hora];
    final sessaoFaltou = SessaoAgendada.fromMap(sessaoFaltouData);
    final agendamentoId = sessaoFaltou.agendamentoId;

    writeBatch.update(refFaltou, {'sessoes.$hora.status': 'Falta Injustificada'});

    final sessoesAgendamento = await _findAllSessionsInAgendamento(agendamentoId);
    final sessoesFuturas = sessoesAgendamento.where((s) {
      final dataSessao = DateFormat('yyyy-MM-dd').parseUtc(s.id);
      return dataSessao.isAfter(dataSessaoFaltou);
    }).toList();

    for (var doc in sessoesFuturas) {
      final sessaoData = (doc.data() as Map<String, dynamic>?)?['sessoes']?[hora];
      if (sessaoData != null) {
        final sessao = SessaoAgendada.fromMap(sessaoData);
        if (sessao.agendamentoId == agendamentoId) {
          writeBatch.update(
              doc.reference, {'sessoes.$hora.sessaoNumero': sessao.sessaoNumero - 1});
        }
      }
    }

    final ultimaSessaoDoc = sessoesAgendamento.last;
    DateTime dataBase =
        DateFormat('yyyy-MM-dd').parseUtc(ultimaSessaoDoc.id).add(const Duration(days: 7));

    int tentativas = 0;
    while (tentativas < 52) {
      if (dataBase.weekday != DateTime.saturday &&
          dataBase.weekday != DateTime.sunday) {
        final docId = DateFormat('yyyy-MM-dd').format(dataBase);
        final docSnapshot =
            await _db.collection(_sessoesAgendadasCollection).doc(docId).get();
        final docData = docSnapshot.data() as Map<String, dynamic>?;
        if (!docSnapshot.exists || docData?['sessoes']?[hora] == null) {
          break;
        }
      }
      dataBase = dataBase.add(const Duration(days: 7));
      tentativas++;
    }

    final novaSessao = SessaoAgendada(
      agendamentoId: agendamentoId,
      agendamentoStartDate: sessaoFaltou.agendamentoStartDate,
      pacienteId: sessaoFaltou.pacienteId,
      pacienteNome: sessaoFaltou.pacienteNome,
      status: 'Agendada',
      sessaoNumero: sessaoFaltou.totalSessoes,
      totalSessoes: sessaoFaltou.totalSessoes,
      formaPagamento: sessaoFaltou.formaPagamento,
      convenio: sessaoFaltou.convenio,
      parcelamento: sessaoFaltou.parcelamento,
      statusPagamento: 'Pendente',
    );
    final novoDocId = DateFormat('yyyy-MM-dd').format(dataBase.toUtc());
    writeBatch.set(_db.collection(_sessoesAgendadasCollection).doc(novoDocId),
        {'sessoes': {hora: novaSessao.toMap()}}, SetOptions(merge: true));

    await writeBatch.commit();
  }

  Future<void> cancelarFaltaInjustificada({required DateTime dataSessao, required String hora}) async {
      final writeBatch = _db.batch();
      final docId = DateFormat('yyyy-MM-dd').format(dataSessao.toUtc());
      final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);

      final docSnapshot = await ref.get();
      final docData = docSnapshot.data() as Map<String, dynamic>?;
      if (docData == null || docData['sessoes']?[hora] == null) {
          throw Exception("Sessão original não encontrada.");
      }
      final agendamentoId = docData['sessoes'][hora]['agendamentoId'];

      writeBatch.update(ref, {'sessoes.$hora.status': 'Agendada'});

      final sessoesDoAgendamento = await _findAllSessionsInAgendamento(agendamentoId);
      
      if (sessoesDoAgendamento.isNotEmpty) {
          final ultimaSessaoDoc = sessoesDoAgendamento.last;
          if (ultimaSessaoDoc.id != docId) {
            writeBatch.update(ultimaSessaoDoc.reference, {'sessoes.$hora': FieldValue.delete()});
          }
      }

      final sessoesAfetadas = sessoesDoAgendamento.where((s) {
          final dataSessaoLoop = DateFormat('yyyy-MM-dd').parseUtc(s.id);
          return dataSessaoLoop.isAfter(dataSessao);
      }).toList();
      
      for (var doc in sessoesAfetadas) {
        final sessaoData = (doc.data() as Map<String, dynamic>?)?['sessoes']?[hora];
        if(sessaoData != null){
            final sessao = SessaoAgendada.fromMap(sessaoData);
            if(sessao.agendamentoId == agendamentoId) {
                if(doc.id != docId) {
                  writeBatch.update(doc.reference, {'sessoes.$hora.sessaoNumero': sessao.sessaoNumero + 1});
                }
            }
        }
      }
      
      await writeBatch.commit();
  }

  Future<void> desmarcarSessaoUnicaEReagendar({required DateTime data, required String hora}) async {
    final writeBatch = _db.batch();
    final docId = DateFormat('yyyy-MM-dd').format(data.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    
    final docSnapshot = await ref.get();
    final docData = docSnapshot.data() as Map<String, dynamic>?;
    if (docData == null || docData['sessoes']?[hora] == null) {
      throw Exception("Sessão original não encontrada.");
    }
    
    final sessaoOriginalData = docData['sessoes'][hora];
    final sessaoOriginal = SessaoAgendada.fromMap(sessaoOriginalData);
    final agendamentoId = sessaoOriginal.agendamentoId;

    writeBatch.update(ref, {'sessoes.$hora.status': 'Desmarcada'});
    
    final sessoesDoAgendamento = await _findAllSessionsInAgendamento(agendamentoId);

    // Re-numera as sessões futuras
    final sessoesFuturas = sessoesDoAgendamento.where((s) {
      final dataSessaoLoop = DateFormat('yyyy-MM-dd').parseUtc(s.id);
      return dataSessaoLoop.isAfter(data);
    }).toList();

    for (var doc in sessoesFuturas) {
      final sessaoData = (doc.data() as Map<String, dynamic>?)?['sessoes']?[hora];
      if (sessaoData != null) {
        final sessao = SessaoAgendada.fromMap(sessaoData);
        if (sessao.agendamentoId == agendamentoId) {
          writeBatch.update(doc.reference, {'sessoes.$hora.sessaoNumero': sessao.sessaoNumero - 1});
        }
      }
    }
    
    // Adiciona uma nova sessão no final
    final ultimaSessaoDoc = sessoesDoAgendamento.last;
    DateTime dataBase = DateFormat('yyyy-MM-dd').parseUtc(ultimaSessaoDoc.id).add(const Duration(days: 7));
    
    int tentativas = 0;
    while(tentativas < 52) {
        if(dataBase.weekday != DateTime.saturday && dataBase.weekday != DateTime.sunday) {
            final proxDocId = DateFormat('yyyy-MM-dd').format(dataBase);
            final proxDocSnapshot = await _db.collection(_sessoesAgendadasCollection).doc(proxDocId).get();
            final proxDocData = proxDocSnapshot.data() as Map<String, dynamic>?;
            if(!proxDocSnapshot.exists || proxDocData?['sessoes']?[hora] == null) {
                break;
            }
        }
        dataBase = dataBase.add(const Duration(days: 7));
        tentativas++;
    }

    final novaSessao = SessaoAgendada(
      agendamentoId: agendamentoId,
      agendamentoStartDate: sessaoOriginal.agendamentoStartDate,
      pacienteId: sessaoOriginal.pacienteId,
      pacienteNome: sessaoOriginal.pacienteNome,
      status: 'Agendada',
      sessaoNumero: sessaoOriginal.totalSessoes,
      totalSessoes: sessaoOriginal.totalSessoes,
      formaPagamento: sessaoOriginal.formaPagamento,
      convenio: sessaoOriginal.convenio,
      parcelamento: sessaoOriginal.parcelamento,
      statusPagamento: 'Pendente',
    );
    final novoDocId = DateFormat('yyyy-MM-dd').format(dataBase.toUtc());
    writeBatch.set(_db.collection(_sessoesAgendadasCollection).doc(novoDocId), {'sessoes': {hora: novaSessao.toMap()}}, SetOptions(merge: true));

    await writeBatch.commit();
  }

  Future<void> reativarSessaoDesmarcada({required DateTime data, required String hora}) async {
    final writeBatch = _db.batch();
    final docId = DateFormat('yyyy-MM-dd').format(data.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    
    final docSnapshot = await ref.get();
    final docData = docSnapshot.data() as Map<String, dynamic>?;
    if (docData == null || docData['sessoes']?[hora] == null) {
      throw Exception("Sessão original não encontrada.");
    }
    final agendamentoId = docData['sessoes'][hora]['agendamentoId'];

    writeBatch.update(ref, {'sessoes.$hora.status': 'Agendada'});

    final sessoesDoAgendamento = await _findAllSessionsInAgendamento(agendamentoId);
    
    if (sessoesDoAgendamento.isNotEmpty) {
      final ultimaSessaoDoc = sessoesDoAgendamento.last;
      writeBatch.update(ultimaSessaoDoc.reference, {'sessoes.$hora': FieldValue.delete()});
    }

    // Re-numera as sessões futuras de volta
    final sessoesFuturas = sessoesDoAgendamento.where((s) {
      final dataSessaoLoop = DateFormat('yyyy-MM-dd').parseUtc(s.id);
      return dataSessaoLoop.isAfter(data);
    }).toList();

    for (var doc in sessoesFuturas) {
      final sessaoData = (doc.data() as Map<String, dynamic>?)?['sessoes']?[hora];
      if (sessaoData != null) {
        final sessao = SessaoAgendada.fromMap(sessaoData);
        if (sessao.agendamentoId == agendamentoId) {
          writeBatch.update(doc.reference, {'sessoes.$hora.sessaoNumero': sessao.sessaoNumero + 1});
        }
      }
    }

    await writeBatch.commit();
  }

  Future<void> desmarcarSessoesRestantes({required DateTime data, required String hora}) async {
    final docId = DateFormat('yyyy-MM-dd').format(data.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    final docSnapshot = await ref.get();
    final docData = docSnapshot.data() as Map<String, dynamic>?;

    if (docData == null || docData['sessoes']?[hora] == null) {
      throw Exception("Sessão original não encontrada para desmarcar as restantes.");
    }
    final agendamentoId = docData['sessoes'][hora]['agendamentoId'];

    final sessoesDoAgendamento = await _findAllSessionsInAgendamento(agendamentoId);

    final writeBatch = _db.batch();
    for (var sessaoDoc in sessoesDoAgendamento) {
      final dataSessao = DateFormat('yyyy-MM-dd').parseUtc(sessaoDoc.id);
      if (!dataSessao.isBefore(data)) {
        final sessaoHoraData = (sessaoDoc.data() as Map<String, dynamic>?)?['sessoes']?[hora];
        if (sessaoHoraData != null && sessaoHoraData['agendamentoId'] == agendamentoId) {
            writeBatch.update(sessaoDoc.reference, {'sessoes.$hora': FieldValue.delete()});
        }
      }
    }
    await writeBatch.commit();
  }
  
  Future<List<DocumentSnapshot>> _findAllSessionsInAgendamento(String agendamentoId) async {
    List<DocumentSnapshot> sessoesEncontradas = [];
    final querySnapshot = await _db.collection(_sessoesAgendadasCollection).get();

    for (var doc in querySnapshot.docs) {
      if (!doc.exists) continue;
      final docData = doc.data() as Map<String, dynamic>?;
      if (docData == null || !docData.containsKey('sessoes')) continue;

      final sessoes = docData['sessoes'] as Map<String, dynamic>;
      sessoes.forEach((hora, sessaoData) {
        if (sessaoData['agendamentoId'] == agendamentoId) {
          if (!sessoesEncontradas.any((d) => d.id == doc.id)) {
            sessoesEncontradas.add(doc);
          }
        }
      });
    }
    sessoesEncontradas.sort((a, b) => a.id.compareTo(b.id));
    return sessoesEncontradas;
  }

  Future<Map<String, List<SessaoComData>>> getSessoesPorPaciente(String pacienteId) async {
    final Map<String, List<SessaoComData>> sessoesAgrupadas = {};
    final querySnapshot = await _db.collection(_sessoesAgendadasCollection).get();

    for (var doc in querySnapshot.docs) {
      if (!doc.exists) continue;
      final docData = doc.data() as Map<String, dynamic>?;
      if (docData == null || !docData.containsKey('sessoes')) continue;

      final dataDaSessao = DateFormat('yyyy-MM-dd').parse(doc.id);
      final sessoesDoDia = docData['sessoes'] as Map<String, dynamic>;

      sessoesDoDia.forEach((hora, sessaoData) {
        if (sessaoData['pacienteId'] == pacienteId) {
          final sessao = SessaoAgendada.fromMap(sessaoData as Map<String, dynamic>);
          final sessaoComData = SessaoComData(sessao, dataDaSessao);

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

    return sessoesAgrupadas;
  }

  Future<void> updateObservacoesSessao({
    required DateTime data,
    required String agendamentoId,
    required String observacoes,
  }) async {
    final docId = DateFormat('yyyy-MM-dd').format(data);
    final docRef = _db.collection(_sessoesAgendadasCollection).doc(docId);

    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) return;

    final sessoes =
        (docSnapshot.data() as Map<String, dynamic>)['sessoes'] as Map<String, dynamic>;
    String? horaSessao;
    sessoes.forEach((hora, sessaoData) {
      if (sessaoData['agendamentoId'] == agendamentoId) {
        horaSessao = hora;
      }
    });

    if (horaSessao != null) {
      await docRef.update({'sessoes.$horaSessao.observacoes': observacoes});
    }
  }

  Future<void> _updateAllSessionsInAgendamento(
      String agendamentoId, Map<String, dynamic> dataToUpdate) async {
    final WriteBatch batch = _db.batch();
    final sessoesDoAgendamento = await _findAllSessionsInAgendamento(agendamentoId);

    for (var doc in sessoesDoAgendamento) {
      final sessoes = (doc.data() as Map<String, dynamic>?)?['sessoes'] as Map<String, dynamic>?;
      if (sessoes == null) continue;

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
  
  Future<void> _updateSingleSession(String docId, String hora, Map<String, dynamic> dataToUpdate) async {
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    final WriteBatch batch = _db.batch();
    dataToUpdate.forEach((key, value) {
      batch.update(ref, {'sessoes.$hora.$key': value});
    });
    await batch.commit();
  }

  Future<void> atualizarPagamentoGuiaConvenio(
      {required String agendamentoId, required Timestamp dataPagamento}) async {
    await _updateAllSessionsInAgendamento(agendamentoId, {
      'dataPagamentoGuia': dataPagamento,
      'statusPagamento': 'Recebido',
    });
  }

  Future<void> cancelarPagamentoGuiaConvenio({required String agendamentoId}) async {
    await _updateAllSessionsInAgendamento(agendamentoId, {
      'dataPagamentoGuia': FieldValue.delete(),
      'statusPagamento': 'Pendente',
    });
  }

  Future<void> atualizarPagamentoParcela(
      {required String agendamentoId,
      required int parcela,
      required Timestamp dataPagamento}) async {
    await _updateAllSessionsInAgendamento(
        agendamentoId, {'pagamentosParcelados.$parcela': dataPagamento});
  }

  Future<void> cancelarPagamentoParcela(
      {required String agendamentoId, required int parcela}) async {
    await _updateAllSessionsInAgendamento(
        agendamentoId, {'pagamentosParcelados.$parcela': null});
  }
  
  Future<void> atualizarPagamentoSessaoUnica(
      {required SessaoAgendada sessao,
      required Timestamp dataPagamento,
      required String hora,
      required DateTime data}) async {
    final docId = DateFormat('yyyy-MM-dd').format(data);
    await _updateSingleSession(docId, hora, {
      'statusPagamento': 'Pago',
      'dataPagamentoSessao': dataPagamento
    });
  }
  
  Future<void> cancelarPagamentoSessaoUnica(
      {required SessaoAgendada sessao, required String hora, required DateTime data}) async {
     final docId = DateFormat('yyyy-MM-dd').format(data);
    await _updateSingleSession(docId, hora, {
      'statusPagamento': 'Pendente',
      'dataPagamentoSessao': FieldValue.delete()
    });
  }

  Future<void> bloquearHorario(DateTime dia, String hora) async {
    final docId = DateFormat('yyyy-MM-dd').format(dia.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    await ref.set({
      'sessoes': {
        hora: {'status': 'Bloqueado'}
      }
    }, SetOptions(merge: true));
  }

  Future<void> desbloquearHorario(DateTime dia, String hora) async {
    final docId = DateFormat('yyyy-MM-dd').format(dia.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    await ref.update({'sessoes.$hora': FieldValue.delete()});
  }

  Future<void> bloquearHorariosEmLote(DateTime dia, List<String> horas) async {
    if (horas.isEmpty) return;
    final docId = DateFormat('yyyy-MM-dd').format(dia.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    final WriteBatch batch = _db.batch();
    final Map<String, dynamic> bloqueios = {
      for (var hora in horas)
        'sessoes.$hora': {'status': 'Bloqueado'}
    };
    batch.update(ref, bloqueios);
    await batch.commit();
  }

  Future<void> desbloquearHorariosEmLote(DateTime dia, List<String> horas) async {
    if (horas.isEmpty) return;
    final docId = DateFormat('yyyy-MM-dd').format(dia.toUtc());
    final ref = _db.collection(_sessoesAgendadasCollection).doc(docId);
    final WriteBatch batch = _db.batch();
    final Map<String, dynamic> desbloqueios = {
      for (var hora in horas) 'sessoes.$hora': FieldValue.delete()
    };
    batch.update(ref, desbloqueios);
    await batch.commit();
  }
    Future<int> getSessoesHojeCount() async {
    final hojeString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await _db.collection(_sessoesAgendadasCollection).doc(hojeString).get();
    if (!doc.exists) return 0;

    final data = doc.data() as Map<String, dynamic>;
    if (data.containsKey('sessoes')) {
      final sessoes = data['sessoes'] as Map<String, dynamic>;
      return sessoes.values.where((s) => s['status'] == 'Agendada').length;
    }
    return 0;
  }

  Future<double> getPagamentosPendentesMes() async {
    // Esta é uma estimativa. Pagamentos por sessão exigem lógica mais complexa
    // que não está implementada (definir preço por sessão).
    // Por enquanto, esta função pode servir como placeholder.
    // Retornando 0 para não mostrar valores incorretos.
    return 0.0;
  }

  Future<String> getProximaVagaDisponivel() async {
    final disponibilidade = await getDisponibilidadePadrao();
    if (disponibilidade.isEmpty) return "Agenda não definida";

    DateTime diaAtual = DateTime.now();
    for (int i = 0; i < 90; i++) { // Procura nos próximos 90 dias
      final nomeDiaSemana = DateFormat('EEEE', 'pt_BR').format(diaAtual).replaceFirstMapped((RegExp(r'^\w')), (match) => match.group(0)!.toUpperCase());
      final horariosDoDia = disponibilidade[nomeDiaSemana] ?? [];

      if (horariosDoDia.isNotEmpty) {
        final docId = DateFormat('yyyy-MM-dd').format(diaAtual);
        final doc = await _db.collection(_sessoesAgendadasCollection).doc(docId).get();
        final sessoesDoDia = doc.exists ? (doc.data() as Map<String, dynamic>)['sessoes'] as Map<String, dynamic> : {};

        for (var hora in horariosDoDia) {
          // Se o horário não está na lista de sessões, está vago
          if (!sessoesDoDia.containsKey(hora)) {
            final dataFormatada = DateFormat("dd/MM 'às'").format(diaAtual);
            return "$dataFormatada $hora";
          }
        }
      }
      diaAtual = diaAtual.add(const Duration(days: 1));
    }
    return "Nenhuma vaga encontrada";
  }

}