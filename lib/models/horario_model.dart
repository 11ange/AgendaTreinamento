// 11ange/agendatreinamento/AgendaTreinamento-f667d20bbd422772da4aba80e9e5223229c98088/lib/models/horario_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa os dados detalhados de uma sessão que foi agendada.
class SessaoAgendada {
  final String agendamentoId;
  final Timestamp agendamentoStartDate;
  final String pacienteId;
  final String pacienteNome;
  String status; // 'Agendada', 'Desmarcada', 'Bloqueado'
  final int sessaoNumero;
  final int totalSessoes;
  final bool reagendada;
  final Timestamp? desmarcadaEm;

  // Novos campos de pagamento
  final String? formaPagamento;
  final String? convenio;
  final String? parcelamento;

  SessaoAgendada({
    required this.agendamentoId,
    required this.agendamentoStartDate,
    required this.pacienteId,
    required this.pacienteNome,
    required this.status,
    required this.sessaoNumero,
    required this.totalSessoes,
    this.reagendada = false,
    this.desmarcadaEm,
    this.formaPagamento,
    this.convenio,
    this.parcelamento,
  });

  /// Cria uma instância a partir de um mapa (geralmente do Firestore).
  factory SessaoAgendada.fromMap(Map<String, dynamic> map) {
    return SessaoAgendada(
      agendamentoId: map['agendamentoId'] ?? '',
      agendamentoStartDate: map['agendamentoStartDate'] ?? Timestamp.now(),
      pacienteId: map['pacienteId'] ?? '',
      pacienteNome: map['pacienteNome'] ?? '',
      status: map['status'] ?? 'disponivel',
      sessaoNumero: map['sessaoNumero'] ?? 0,
      totalSessoes: map['totalSessoes'] ?? 0,
      reagendada: map['reagendada'] ?? false,
      desmarcadaEm: map['desmarcadaEm'],
      formaPagamento: map['formaPagamento'],
      convenio: map['convenio'],
      parcelamento: map['parcelamento'],
    );
  }

  /// Converte a instância em um mapa para ser salvo no Firestore.
  Map<String, dynamic> toMap() {
    return {
      'agendamentoId': agendamentoId,
      'agendamentoStartDate': agendamentoStartDate,
      'pacienteId': pacienteId,
      'pacienteNome': pacienteNome,
      'status': status,
      'sessaoNumero': sessaoNumero,
      'totalSessoes': totalSessoes,
      'reagendada': reagendada,
      if (desmarcadaEm != null) 'desmarcadaEm': desmarcadaEm,
      if (formaPagamento != null) 'formaPagamento': formaPagamento,
      if (convenio != null) 'convenio': convenio,
      if (parcelamento != null) 'parcelamento': parcelamento,
    };
  }
}

/// Representa um slot de horário na agenda.
/// Pode ou não conter uma sessão agendada.
class Horario {
  final String hora;
  final SessaoAgendada? sessaoAgendada;

  Horario({required this.hora, this.sessaoAgendada});

  // Getters para facilitar o acesso aos dados na UI
  bool get isBooked => sessaoAgendada != null;
  String get status => sessaoAgendada?.status ?? 'disponivel';
  String? get agendamentoId => sessaoAgendada?.agendamentoId;
  String? get pacienteId => sessaoAgendada?.pacienteId;
  String? get pacienteNome => sessaoAgendada?.pacienteNome;
  int? get sessaoNumero => sessaoAgendada?.sessaoNumero;
  int? get totalSessoes => sessaoAgendada?.totalSessoes;
  bool get reagendada => sessaoAgendada?.reagendada ?? false;
  Timestamp? get agendamentoStartDate => sessaoAgendada?.agendamentoStartDate;
  Timestamp? get desmarcadaEm => sessaoAgendada?.desmarcadaEm;
}