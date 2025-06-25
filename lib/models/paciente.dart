import 'package:cloud_firestore/cloud_firestore.dart';

class Paciente {
  final String? id;
  final String nome;
  final int idade;
  final String dataNascimento;
  final String nomeResponsavel;
  final String telefoneResponsavel;
  final String? emailResponsavel;
  final String afinandoCerebro;
  final String? observacoes;
  final DateTime dataCadastro;

  Paciente({
    this.id,
    required this.nome,
    required this.idade,
    required this.dataNascimento,
    required this.nomeResponsavel,
    required this.telefoneResponsavel,
    this.emailResponsavel,
    required this.afinandoCerebro,
    this.observacoes,
    required this.dataCadastro,
  });

  // Converte um Documento do Firestore para um objeto Paciente
  factory Paciente.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Paciente(
      id: snapshot.id,
      nome: data['nome'] ?? '',
      idade: data['idade'] ?? 0,
      dataNascimento: data['dataNascimento'] ?? '',
      nomeResponsavel: data['nomeResponsavel'] ?? '',
      telefoneResponsavel: data['telefoneResponsavel'] ?? '',
      emailResponsavel: data['emailResponsavel'],
      afinandoCerebro: data['afinandoCerebro'] ?? '',
      observacoes: data['observacoes'],
      dataCadastro: (data['dataCadastro'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Converte um objeto Paciente para um Map para o Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'idade': idade,
      'dataNascimento': dataNascimento,
      'nomeResponsavel': nomeResponsavel,
      'telefoneResponsavel': telefoneResponsavel,
      if (emailResponsavel != null) 'emailResponsavel': emailResponsavel,
      'afinandoCerebro': afinandoCerebro,
      if (observacoes != null) 'observacoes': observacoes,
      'dataCadastro': dataCadastro,
    };
  }
}