import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import necessário para o DateFormat

class CadastroPacientesPage extends StatefulWidget {
  final String? pacienteId;
  final Map<String, dynamic>? pacienteData;

  const CadastroPacientesPage({super.key, this.pacienteId, this.pacienteData});

  @override
  State<CadastroPacientesPage> createState() => _CadastroPacientesPageState();
}

class _CadastroPacientesPageState extends State<CadastroPacientesPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomePacienteController = TextEditingController();
  final _idadePacienteController = TextEditingController();
  final _dataNascimentoPacienteController = TextEditingController();
  final _telefoneResponsavelController = TextEditingController();
  final _emailResponsavelController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _nomeResponsavelController = TextEditingController();
  final _convenioController = TextEditingController();
  String? _formaPagamentoValue;
  String? _afinandoCerebroValue;
  String? _parcelamentoValue;

  @override
  void initState() {
    super.initState();
    if (widget.pacienteData != null) {
      final data = widget.pacienteData!;
      _nomePacienteController.text = data['nome'] ?? '';
      _idadePacienteController.text = data['idade']?.toString() ?? '';
      _dataNascimentoPacienteController.text = data['dataNascimento'] ?? '';
      _telefoneResponsavelController.text = data['telefoneResponsavel'] ?? '';
      _emailResponsavelController.text = data['emailResponsavel'] ?? '';
      _observacoesController.text = data['observacoes'] ?? '';
      _nomeResponsavelController.text = data['nomeResponsavel'] ?? '';
      _afinandoCerebroValue = data['afinandoCerebro'];
      _convenioController.text = data['convenio'] ?? '';
      _formaPagamentoValue = data['formaPagamento'];
      _parcelamentoValue = data['parcelamento'];
    }
  }

  @override
  void dispose() {
    _nomePacienteController.dispose();
    _idadePacienteController.dispose();
    _dataNascimentoPacienteController.dispose();
    _telefoneResponsavelController.dispose();
    _emailResponsavelController.dispose();
    _observacoesController.dispose();
    _nomeResponsavelController.dispose();
    _convenioController.dispose();
    super.dispose();
  }

  Future<void> _salvarPaciente() async {
    if (_formKey.currentState!.validate()) {
      try {
        final paciente = {
          'nome': _nomePacienteController.text,
          'idade': int.tryParse(_idadePacienteController.text) ?? 0,
          'dataNascimento': _dataNascimentoPacienteController.text,
          'telefoneResponsavel': _telefoneResponsavelController.text,
          'emailResponsavel': _emailResponsavelController.text,
          'observacoes': _observacoesController.text,
          'nomeResponsavel': _nomeResponsavelController.text,
          'convenio': _convenioController.text,
          'afinandoCerebro': _afinandoCerebroValue,
          'formaPagamento': _formaPagamentoValue,
          'parcelamento': _parcelamentoValue,
        };

        if (widget.pacienteId == null) {
          paciente['dataCadastro'] = DateTime.now();
          await FirebaseFirestore.instance.collection('pacientes').add(paciente);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paciente cadastrado com sucesso!')),
            );
          }
        } else {
          await FirebaseFirestore.instance.collection('pacientes').doc(widget.pacienteId).update(paciente);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paciente atualizado com sucesso!')),
            );
          }
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar paciente: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos obrigatórios.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const EdgeInsets defaultContentPadding =
        EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pacienteId == null ? 'Cadastro de Paciente' : 'Editar Paciente'),
        centerTitle: true,
      ),
      // --- OTIMIZAÇÃO APLICADA AQUI ---
      body: Center( // 1. Centraliza o conteúdo na tela
        child: ConstrainedBox( // 2. Limita a largura máxima do conteúdo
          constraints: const BoxConstraints(maxWidth: 700), // Valor ideal para formulários
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Nome Paciente:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _nomePacienteController,
                      decoration: const InputDecoration(hintText: 'Nome completo do paciente', border: OutlineInputBorder(), isDense: true, contentPadding: defaultContentPadding),
                      validator: (v) => (v == null || v.isEmpty) ? 'Nome é obrigatório' : null,
                    ),
                    const SizedBox(height: 15),

                    const Text('Idade Paciente:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _idadePacienteController,
                      decoration: const InputDecoration(hintText: 'Idade do paciente', border: OutlineInputBorder(), isDense: true, contentPadding: defaultContentPadding),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? 'Insira uma idade válida' : null,
                    ),
                    const SizedBox(height: 15),

                    const Text('Data de Nascimento:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _dataNascimentoPacienteController,
                      decoration: const InputDecoration(
                        hintText: 'DD/MM/AAAA',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                        isDense: true,
                        contentPadding: defaultContentPadding,
                      ),
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
                          String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
                          setState(() => _dataNascimentoPacienteController.text = formattedDate);
                        }
                      },
                      validator: (v) => (v == null || v.isEmpty) ? 'Data de nascimento é obrigatória' : null,
                    ),
                    const SizedBox(height: 15),

                    const Text('Nome do Responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _nomeResponsavelController,
                      decoration: const InputDecoration(hintText: 'Nome completo do responsável', border: OutlineInputBorder(), isDense: true, contentPadding: defaultContentPadding),
                      validator: (v) => (v == null || v.isEmpty) ? 'Nome do responsável é obrigatório' : null,
                    ),
                    const SizedBox(height: 15),

                    const Text('Telefone do Responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _telefoneResponsavelController,
                      decoration: const InputDecoration(hintText: 'Número de telefone do Responsável', border: OutlineInputBorder(), isDense: true, contentPadding: defaultContentPadding),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.isEmpty) ? 'Telefone é obrigatório' : null,
                    ),
                    const SizedBox(height: 15),

                    const Text('Email do Responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _emailResponsavelController,
                      decoration: const InputDecoration(hintText: 'Endereço de email (opcional)', border: OutlineInputBorder(), isDense: true, contentPadding: defaultContentPadding),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 15),

                    const Text('Forma de pagamento:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String>(
                      value: _formaPagamentoValue,
                      items: const [
                        DropdownMenuItem(value: 'Dinheiro', child: Text('Dinheiro')),
                        DropdownMenuItem(value: 'PIX', child: Text('PIX')),
                        DropdownMenuItem(value: 'Convênio', child: Text('Convênio')),
                      ],
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Selecione uma opção', isDense: true, contentPadding: defaultContentPadding),
                      onChanged: (String? newValue) => setState(() => _formaPagamentoValue = newValue),
                      validator: (v) => (v == null || v.isEmpty) ? 'Forma de pagamento é obrigatória' : null,
                    ),
                    const SizedBox(height: 15),

                    const Text('Nome do Convênio:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _convenioController,
                      decoration: const InputDecoration(hintText: 'Nome do Convênio (se aplicável)', border: OutlineInputBorder(), isDense: true, contentPadding: defaultContentPadding),
                    ),
                    const SizedBox(height: 15),

                    const Text('Parcelamento:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String>(
                      value: _parcelamentoValue,
                      items: const [
                        DropdownMenuItem(value: 'Sessão', child: Text('Por Sessão')),
                        DropdownMenuItem(value: '3x', child: Text('3x')),
                      ],
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Selecione o parcelamento', isDense: true, contentPadding: defaultContentPadding),
                      onChanged: (String? newValue) => setState(() => _parcelamentoValue = newValue),
                    ),
                    const SizedBox(height: 15),

                    const Text('Afinando o Cérebro:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String>(
                      value: _afinandoCerebroValue,
                      items: const [
                        DropdownMenuItem(value: 'Não enviado', child: Text('Não enviado')),
                        DropdownMenuItem(value: 'Enviado', child: Text('Enviado')),
                        DropdownMenuItem(value: 'Cadastrado', child: Text('Cadastrado')),
                      ],
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Selecione uma opção', isDense: true, contentPadding: defaultContentPadding),
                      onChanged: (String? newValue) => setState(() => _afinandoCerebroValue = newValue),
                      validator: (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 15),

                    const Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _observacoesController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Informações adicionais (opcional)', border: OutlineInputBorder(), contentPadding: defaultContentPadding),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _salvarPaciente,
                        child: Text(widget.pacienteId == null ? 'Salvar Paciente' : 'Atualizar Paciente'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}