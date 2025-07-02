import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'evolucao_paciente.dart';

class PacientesInativosPage extends StatefulWidget {
  const PacientesInativosPage({super.key});

  @override
  State<PacientesInativosPage> createState() => _PacientesInativosPageState();
}

class _PacientesInativosPageState extends State<PacientesInativosPage> {
  Future<void> _reativarPaciente(String docId, String nome) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Reativação'),
          content: Text('Deseja reativar o paciente "$nome"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim, Reativar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        await FirebaseFirestore.instance
            .collection('pacientes')
            .doc(docId)
            .update({'status': 'ativo'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paciente reativado com sucesso.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao reativar paciente: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0),
        child: AppBar(
          title: const Text('Pacientes Inativos'),
          centerTitle: true,
          backgroundColor: Colors.grey.shade700,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pacientes')
                  .where('status', isEqualTo: 'inativo')
                  .orderBy('nome')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Ocorreu um erro: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('Nenhum paciente inativo encontrado.'));
                }

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final pacienteNome = data['nome'] ?? 'Nome não informado';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 6.0),
                      child: ListTile(
                        title: Text(pacienteNome,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Responsável: ${data['nomeResponsavel'] ?? 'N/A'}'),
                            Text(
                                'Telefone: ${data['telefoneResponsavel'] ?? 'N/A'}'),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EvolucaoPacientePage(
                                pacienteId: doc.id,
                                pacienteNome: pacienteNome,
                              ),
                            ),
                          );
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.history, color: Colors.green),
                          tooltip: 'Reativar Paciente',
                          onPressed: () => _reativarPaciente(doc.id, pacienteNome),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}