import 'package:flutter/material.dart';
import 'cadastro_pacientes.dart';
import 'pacientes.dart'; // Importe a página de pacientes
import 'cadastro_agenda.dart'; // Importe a página de agenda semanal
import 'sessoes.dart'; // Importe a página de sessões

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tela Inicial'), // Título da AppBar
        centerTitle: true, // Centraliza o título da AppBar
        backgroundColor: Colors.blue, // Cor de fundo da AppBar
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16.0), // Espaçamento interno do retângulo
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey), // Borda do retângulo
            borderRadius: BorderRadius.circular(8.0), // Bordas arredondadas (opcional)
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ajusta a altura da Column ao conteúdo
            crossAxisAlignment: CrossAxisAlignment.start, // Alinha o texto à esquerda
            children: <Widget>[
              const Text(
                'Cadastros:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 10), // Espaço entre o texto e os botões
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround, // Espaço entre os botões na linha
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      print('Botão Pacientes clicado!');
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PacientesPage()));
                    },
                    child: const Text('Pacientes'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      print('Botão Sessões clicado!');
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const Sessoes()));
                    },
                    child: const Text('Sessões'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      print('Botão Agenda clicado!');
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendaSemanalPage()));
                    },
                    child: const Text('Agenda'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}