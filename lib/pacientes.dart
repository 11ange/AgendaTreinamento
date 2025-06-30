import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'evolucao_paciente.dart';

class PacientesPage extends StatefulWidget {
  const PacientesPage({super.key});

  @override
  State<PacientesPage> createState() => _PacientesPageState();
}

class _PacientesPageState extends State<PacientesPage> {
  // Função para calcular a idade
  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _showAddOrEditPacienteDialog(
      {String? docId, Map<String, dynamic>? initialData}) async {
    final formKey = GlobalKey<FormState>();
    final isEditing = docId != null;

    final nomeController = TextEditingController(text: initialData?['nome'] ?? '');
    final dataNascimentoController =
        TextEditingController(text: initialData?['dataNascimento'] ?? '');
    final nomeResponsavelController =
        TextEditingController(text: initialData?['nomeResponsavel'] ?? '');
    final telefoneResponsavelController =
        TextEditingController(text: initialData?['telefoneResponsavel'] ?? '');
    final emailResponsavelController =
        TextEditingController(text: initialData?['emailResponsavel'] ?? '');
    final observacoesController =
        TextEditingController(text: initialData?['observacoes'] ?? '');
    String? afinandoCerebroValue = initialData?['afinandoCerebro'];

    int? calculatedAge;
    if (initialData?['dataNascimento'] != null &&
        initialData!['dataNascimento'].isNotEmpty) {
      final birthDate =
          DateFormat('dd/MM/yyyy').parse(initialData['dataNascimento']);
      calculatedAge = _calculateAge(birthDate);
    }

    return showDialog(
      context: context,
      builder: (context) {
        // Usando StatefulBuilder para atualizar a idade em tempo real dentro do dialog
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Paciente' : 'Novo Paciente'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nomeController,
                        decoration:
                            const InputDecoration(labelText: 'Nome do Paciente'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                      ),
                      TextFormField(
                        controller: dataNascimentoController,
                        decoration: const InputDecoration(
                            labelText: 'Data de Nascimento', hintText: 'DD/MM/AAAA'),
                        readOnly: true,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                        onTap: () async {
                          // Esconde o teclado antes de abrir o date picker
                          FocusScope.of(context).requestFocus(FocusNode());

                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            locale: const Locale('pt', 'BR'),
                          );
                          if (pickedDate != null) {
                            // Atualiza o controller e a idade na tela
                            setStateInDialog(() {
                              dataNascimentoController.text =
                                  DateFormat('dd/MM/yyyy').format(pickedDate);
                              calculatedAge = _calculateAge(pickedDate);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      // Campo para exibir a idade calculada
                      if (calculatedAge != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Idade: $calculatedAge anos',
                            style: TextStyle(
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nomeResponsavelController,
                        decoration:
                            const InputDecoration(labelText: 'Nome do Responsável'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                      ),
                      TextFormField(
                        controller: telefoneResponsavelController,
                        decoration: const InputDecoration(
                            labelText: 'Telefone do Responsável'),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: emailResponsavelController,
                        decoration: const InputDecoration(
                            labelText: 'Email do Responsável'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      DropdownButtonFormField<String>(
                        value: afinandoCerebroValue,
                        decoration:
                            const InputDecoration(labelText: 'Afinando o Cérebro'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Não enviado', child: Text('Não enviado')),
                          DropdownMenuItem(
                              value: 'Enviado', child: Text('Enviado')),
                          DropdownMenuItem(
                              value: 'Cadastrado', child: Text('Cadastrado')),
                        ],
                        onChanged: (String? newValue) {
                          setStateInDialog(() {
                            afinandoCerebroValue = newValue;
                          });
                        },
                        validator: (v) => v == null ? 'Campo obrigatório' : null,
                      ),
                      TextFormField(
                        controller: observacoesController,
                        decoration: const InputDecoration(labelText: 'Observações'),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final pacienteData = {
                        'nome': nomeController.text,
                        'idade': calculatedAge,
                        'dataNascimento': dataNascimentoController.text,
                        'nomeResponsavel': nomeResponsavelController.text,
                        'telefoneResponsavel': telefoneResponsavelController.text,
                        'emailResponsavel': emailResponsavelController.text,
                        'afinandoCerebro': afinandoCerebroValue,
                        'observacoes': observacoesController.text,
                      };

                      if (isEditing) {
                        await FirebaseFirestore.instance
                            .collection('pacientes')
                            .doc(docId)
                            .update(pacienteData);
                      } else {
                        pacienteData['dataCadastro'] = Timestamp.now();
                        await FirebaseFirestore.instance
                            .collection('pacientes')
                            .add(pacienteData);
                      }
                      if (mounted) Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deletePaciente(String documentId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text(
              'Tem certeza que deseja excluir este paciente? Esta ação não pode ser desfeita.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim, Excluir'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('pacientes')
            .doc(documentId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paciente excluído com sucesso.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir paciente: $e')),
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
          title: const Text('Pacientes'),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddOrEditPacienteDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Novo Paciente'),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pacientes')
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
                      child: Text('Nenhum paciente cadastrado.'));
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_note,
                                  color: Colors.blueGrey),
                              tooltip: 'Editar Cadastro do Paciente',
                              onPressed: () => _showAddOrEditPacienteDialog(
                                  docId: doc.id, initialData: data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              tooltip: 'Excluir Paciente',
                              onPressed: () => _deletePaciente(doc.id),
                            ),
                          ],
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