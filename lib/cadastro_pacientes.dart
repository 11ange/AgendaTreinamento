import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui'; // Import para Locale

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
    print('Dados recebidos para edição (CadastroPacientesPage): ${widget.pacienteData}');
    print('Tipo de idade: ${widget.pacienteData?['idade'].runtimeType}');
    if (widget.pacienteData != null) {
      _nomePacienteController.text = widget.pacienteData?['nome'] ?? '';
      _idadePacienteController.text = widget.pacienteData?['idade']?.toString() ?? '';
      _dataNascimentoPacienteController.text = widget.pacienteData?['dataNascimento'] ?? '';
      _telefoneResponsavelController.text = widget.pacienteData?['telefoneResponsavel'] ?? '';
      _emailResponsavelController.text = widget.pacienteData?['emailResponsavel'] ?? '';
      _observacoesController.text = widget.pacienteData?['observacoes'] ?? '';
      _nomeResponsavelController.text = widget.pacienteData?['nomeResponsavel'] ?? '';
      _afinandoCerebroValue = widget.pacienteData?['afinandoCerebro'];
      _convenioController.text = widget.pacienteData?['convenio'] ?? '';
      _formaPagamentoValue = widget.pacienteData?['formaPagamento'];
      _parcelamentoValue = widget.pacienteData?['parcelamento'];
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paciente cadastrado com sucesso!')),
          );
        } else {
          await FirebaseFirestore.instance.collection('pacientes').doc(widget.pacienteId).update(paciente);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paciente atualizado com sucesso!')),
          );
        }
        _nomePacienteController.clear();
        _idadePacienteController.clear();
        _dataNascimentoPacienteController.clear();
        _telefoneResponsavelController.clear();
        _emailResponsavelController.clear();
        _observacoesController.clear();
        _nomeResponsavelController.clear();
        _convenioController.clear();
        setState(() {
          _afinandoCerebroValue = null;
          _formaPagamentoValue = null;
          _parcelamentoValue = null;
        });
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar paciente: $e')),
        );
        print('Erro ao salvar paciente: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos obrigatórios.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definindo um contentPadding padrão para reuso.
    // Isso ajuda a manter os campos compactos após remover as constraints.
    const EdgeInsets _defaultContentPadding =
        EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pacienteId == null ? 'Cadastro de Paciente' : 'Editar Paciente'),
        centerTitle: true,
      ),
      body: Padding(
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
                  decoration: const InputDecoration(
                    hintText: 'Nome completo do paciente',
                    border: OutlineInputBorder(),
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nome é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                const Text('Idade Paciente:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _idadePacienteController,
                  decoration: const InputDecoration(
                    hintText: 'Idade do paciente',
                    border: OutlineInputBorder(),
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Idade é obrigatória';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Insira uma idade válida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                const Text('Data de Nascimento:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _dataNascimentoPacienteController,
                  decoration: const InputDecoration(
                    hintText: 'DD/MM/AAAA',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
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
                      String formattedDate = "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
                      setState(() {
                        _dataNascimentoPacienteController.text = formattedDate;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Data de nascimento é obrigatória';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                const Text('Nome do Responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _nomeResponsavelController,
                  decoration: const InputDecoration(
                    hintText: 'Nome completo do responsável',
                    border: OutlineInputBorder(),
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nome do responsável é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                const Text('Telefone do Responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _telefoneResponsavelController,
                  decoration: const InputDecoration(
                    hintText: 'Número de telefone do Responsável',
                    border: OutlineInputBorder(),
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Telefone é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                const Text('Email do Responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _emailResponsavelController,
                  decoration: const InputDecoration(
                    hintText: 'Endereço de email do Responsável (opcional)',
                    border: OutlineInputBorder(),
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
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
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Selecione uma opção',
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _formaPagamentoValue = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Forma de pagamento é obrigatória';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                const Text('Nome do Convênio:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _convenioController,
                  decoration: const InputDecoration(
                    hintText: 'Nome do Convênio',
                    border: OutlineInputBorder(),
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
                ),
                const SizedBox(height: 15),

                const Text('Parcelamento:', style: TextStyle(fontWeight: FontWeight.bold)),
                FormField<String>(
                  initialValue: _parcelamentoValue,
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione uma opção de parcelamento';
                    }
                    return null;
                  },
                  builder: (FormFieldState<String> state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        CheckboxListTile(
                          title: const Text('Sessão'),
                          value: _parcelamentoValue == 'sessao',
                          onChanged: (bool? newValue) {
                            setState(() {
                              _parcelamentoValue = newValue == true ? 'sessao' : null;
                              state.didChange(_parcelamentoValue);
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          title: const Text('3x'),
                          value: _parcelamentoValue == '3x',
                          onChanged: (bool? newValue) {
                            setState(() {
                              _parcelamentoValue = newValue == true ? '3x' : null;
                              state.didChange(_parcelamentoValue);
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                            child: Text(
                              state.errorText!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                            ),
                          ),
                      ],
                    );
                  },
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
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Selecione uma opção',
                    // constraints: BoxConstraints(maxHeight: 40.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _afinandoCerebroValue = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Afinando o Cérebro é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                const Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _observacoesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Informações adicionais (opcional)',
                    border: OutlineInputBorder(),
                    // constraints: const BoxConstraints(maxHeight: 80.0), // REMOVIDO!
                    isDense: true,
                    contentPadding: _defaultContentPadding, // Usando o padding padrão
                  ),
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
    );
  }
}