// 11ange/agendatreinamento/AgendaTreinamento-f667d20bbd422772da4aba80e9e5223229c98088/lib/pacientes.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PacientesPage extends StatefulWidget {
  const PacientesPage({super.key});

  @override
  State<PacientesPage> createState() => _PacientesPageState();
}

class _PacientesPageState extends State<PacientesPage> {
  
  Future<void> _showAddOrEditPacienteDialog({String? docId, Map<String, dynamic>? initialData}) async {
    final formKey = GlobalKey<FormState>();
    final isEditing = docId != null;

    // Controllers com os dados iniciais (se for edição)
    final nomeController = TextEditingController(text: initialData?['nome'] ?? '');
    final idadeController = TextEditingController(text: initialData?['idade']?.toString() ?? '');
    final dataNascimentoController = TextEditingController(text: initialData?['dataNascimento'] ?? '');
    final nomeResponsavelController = TextEditingController(text: initialData?['nomeResponsavel'] ?? '');
    final telefoneResponsavelController = TextEditingController(text: initialData?['telefoneResponsavel'] ?? '');
    final emailResponsavelController = TextEditingController(text: initialData?['emailResponsavel'] ?? '');
    final observacoesController = TextEditingController(text: initialData?['observacoes'] ?? '');
    String? afinandoCerebroValue = initialData?['afinandoCerebro'];


    return showDialog(
      context: context,
      builder: (context) {
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
                    decoration: const InputDecoration(labelText: 'Nome do Paciente'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                  ),
                  TextFormField(
                    controller: idadeController,
                    decoration: const InputDecoration(labelText: 'Idade'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: dataNascimentoController,
                    decoration: const InputDecoration(labelText: 'Data de Nascimento', hintText: 'DD/MM/AAAA'),
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        locale: const Locale('pt', 'BR'),
                      );
                      if (pickedDate != null) {
                        dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
                      }
                    },
                  ),
                  TextFormField(
                    controller: nomeResponsavelController,
                    decoration: const InputDecoration(labelText: 'Nome do Responsável'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                  ),
                   TextFormField(
                    controller: telefoneResponsavelController,
                    decoration: const InputDecoration(labelText: 'Telefone do Responsável'),
                    keyboardType: TextInputType.phone,
                     validator: (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                  ),
                   TextFormField(
                    controller: emailResponsavelController,
                    decoration: const InputDecoration(labelText: 'Email do Responsável'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  // Usando StatefulBuilder para o Dropdown funcionar dentro do AlertDialog
                  StatefulBuilder(builder: (context, setStateInDialog) {
                    return DropdownButtonFormField<String>(
                      value: afinandoCerebroValue,
                      decoration: const InputDecoration(labelText: 'Afinando o Cérebro'),
                      items: const [
                        DropdownMenuItem(value: 'Não enviado', child: Text('Não enviado')),
                        DropdownMenuItem(value: 'Enviado', child: Text('Enviado')),
                        DropdownMenuItem(value: 'Cadastrado', child: Text('Cadastrado')),
                      ],
                      onChanged: (String? newValue) {
                        setStateInDialog(() {
                          afinandoCerebroValue = newValue;
                        });
                      },
                      validator: (v) => v == null ? 'Campo obrigatório' : null,
                    );
                  }),
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
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if(formKey.currentState!.validate()){
                  final pacienteData = {
                    'nome': nomeController.text,
                    'idade': int.tryParse(idadeController.text) ?? 0,
                    'dataNascimento': dataNascimentoController.text,
                    'nomeResponsavel': nomeResponsavelController.text,
                    'telefoneResponsavel': telefoneResponsavelController.text,
                    'emailResponsavel': emailResponsavelController.text,
                    'afinandoCerebro': afinandoCerebroValue,
                    'observacoes': observacoesController.text,
                  };

                  if(isEditing){
                    await FirebaseFirestore.instance.collection('pacientes').doc(docId).update(pacienteData);
                  } else {
                    pacienteData['dataCadastro'] = Timestamp.now();
                    await FirebaseFirestore.instance.collection('pacientes').add(pacienteData);
                  }
                  if(mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Salvar'),
            ),
          ],
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
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paciente excluído com sucesso.')),
          );
        }
      } catch (e) {
         if(mounted) {
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
              stream: FirebaseFirestore.instance.collection('pacientes').orderBy('nome').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ocorreu um erro: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhum paciente cadastrado.'));
                }

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: ListTile(
                        title: Text(data['nome'] ?? 'Nome não informado', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Responsável: ${data['nomeResponsavel'] ?? 'N/A'}'),
                        onTap: () => _showAddOrEditPacienteDialog(docId: doc.id, initialData: data),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Excluir Paciente',
                          onPressed: () => _deletePaciente(doc.id),
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