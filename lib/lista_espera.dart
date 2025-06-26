import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListaEsperaPage extends StatefulWidget {
  const ListaEsperaPage({super.key});

  @override
  State<ListaEsperaPage> createState() => _ListaEsperaPageState();
}

class _ListaEsperaPageState extends State<ListaEsperaPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- FUNÇÃO PARA ADICIONAR (sem alterações) ---
  Future<void> _adicionarPessoa() async {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController();
    final telefoneController = TextEditingController();
    final observacoesController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar à Lista de Espera'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  TextFormField(
                    controller: telefoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                    keyboardType: TextInputType.phone,
                     validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  TextFormField(
                    controller: observacoesController,
                    decoration: const InputDecoration(labelText: 'Observações (opcional)'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _firestore.collection('lista_espera').add({
                    'nome': nomeController.text,
                    'telefone': telefoneController.text,
                    'observacoes': observacoesController.text,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Adicionado à lista de espera!')),
                    );
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  // --- NOVA FUNÇÃO PARA EDITAR ---
  Future<void> _editarPessoa(String docId, Map<String, dynamic> data) async {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(text: data['nome']);
    final telefoneController = TextEditingController(text: data['telefone']);
    final observacoesController = TextEditingController(text: data['observacoes']);

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Registro'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  TextFormField(
                    controller: telefoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  TextFormField(
                    controller: observacoesController,
                    decoration: const InputDecoration(labelText: 'Observações (opcional)'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _firestore.collection('lista_espera').doc(docId).update({
                    'nome': nomeController.text,
                    'telefone': telefoneController.text,
                    'observacoes': observacoesController.text,
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Registro atualizado!')),
                    );
                  }
                }
              },
              child: const Text('Atualizar'),
            ),
          ],
        );
      },
    );
  }

  // --- FUNÇÃO PARA APAGAR (sem alterações na lógica) ---
  Future<void> _apagarPessoa(String docId, String nome) async {
    final bool? confirmar = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja remover "$nome" da lista de espera?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sim, remover'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await _firestore.collection('lista_espera').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$nome" removido(a) da lista.')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Espera'),
        backgroundColor: Colors.blue, // Cor de fundo da AppBar
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _adicionarPessoa,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar à Lista de Espera'),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('lista_espera').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('A lista de espera está vazia.'),
                  );
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: ListTile(
                        // --- AÇÃO DE CLIQUE ATUALIZADA ---
                        onTap: () => _editarPessoa(docId, data),
                        title: Text(data['nome'] ?? 'Nome não informado'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text('Telefone: ${data['telefone'] ?? 'N/A'}'),
                             if (data['observacoes'] != null && data['observacoes'].isNotEmpty)
                               Padding(
                                 padding: const EdgeInsets.only(top: 4.0),
                                 child: Text('Obs: ${data['observacoes']}', style: const TextStyle(fontStyle: FontStyle.italic)),
                               ),
                          ],
                        ),
                        // --- ÍCONE DE LIXEIRA AGORA É UM BOTÃO ---
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Remover da lista',
                          onPressed: () => _apagarPessoa(docId, data['nome']),
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
    );
  }
}