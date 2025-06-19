import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cadastro_pacientes.dart';

class PacientesPage extends StatefulWidget {
  const PacientesPage({super.key});

  @override
  State<PacientesPage> createState() => _PacientesPageState();
}

class _PacientesPageState extends State<PacientesPage> {
  int? _selectedItemIndex;
  QuerySnapshot? _latestSnapshot;
  final double _tableFontSize = 12.0;
  final double _tableHeaderFontSize = 12.0;
  final double _tableRowHeight = 30.0; // Altura fixa para as linhas

  void _editPaciente(String? documentId, Map<String, dynamic>? pacienteData) {
    if (documentId != null && pacienteData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CadastroPacientesPage(
            pacienteId: documentId,
            pacienteData: pacienteData,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um paciente para editar.')),
      );
    }
  }

  void _deletePaciente(String documentId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Tem certeza que deseja excluir este paciente?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('pacientes').doc(documentId).delete();
        setState(() {
          _selectedItemIndex = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paciente excluído com sucesso.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir paciente: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0), 
        child: AppBar(
          title: const Text('Pacientes'),
          centerTitle: true,
          backgroundColor: Colors.blue, // Cor de fundo da AppBar
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CadastroPacientesPage()),
                    );
                  },
                  child: const Text('Novo Paciente'),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Nome',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: _tableHeaderFontSize),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Idade',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: _tableHeaderFontSize),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Responsável',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: _tableHeaderFontSize),
                            ),
                          ),
                          SizedBox(width: 60),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('pacientes').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(child: Text('Ocorreu um erro ao buscar os pacientes: ${snapshot.error}'));
                            }

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(child: Text('Nenhum paciente cadastrado.'));
                            }

                            _latestSnapshot = snapshot.data;

                            return ListView.builder(
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                final DocumentSnapshot document = snapshot.data!.docs[index];
                                final Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};
                                final String id = document.id;
                                final String nome = data['nome'] ?? '';
                                final int idade = data['idade']?.toInt() ?? 0;
                                final String responsavel = data['nomeResponsavel'] ?? '';
                                final isSelected = _selectedItemIndex == index;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedItemIndex = index;
                                    });
                                  },
                                  child: Container(
                                    height: _tableRowHeight, // Defini a altura fixa
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.grey[200] : null, // Destaque
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0), // Adicionei padding horizontal
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            nome,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(fontSize: _tableFontSize),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '$idade',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: _tableFontSize),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            responsavel,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(fontSize: _tableFontSize),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60.0,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              if (isSelected)
                                                Flexible(
                                                  child: IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                                    onPressed: () => _editPaciente(id, data),
                                                    iconSize: 14.0,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                                  ),
                                                ),
                                              if (isSelected)
                                                Flexible(
                                                  child: IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red),
                                                    onPressed: () => _deletePaciente(id),
                                                    iconSize: 14.0,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}