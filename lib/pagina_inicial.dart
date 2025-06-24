// 11ange/agendatreinamento/AgendaTreinamento-f667d20bbd422772da4aba80e9e5223229c98088/lib/pagina_inicial.dart
import 'package:flutter/material.dart';
import 'cadastro_pacientes.dart';
import 'pacientes.dart'; // Importe a página de pacientes
import 'cadastro_agenda.dart'; // Importe a página de agenda semanal
import 'sessoes.dart'; // Importe a página de sessões
import 'lista_espera.dart'; // Importe a nova página da lista de espera

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0), 
        child: AppBar(
          title: const Text('Tela Inicial'),
          centerTitle: true,
          backgroundColor: Colors.blue, // Cor de fundo da AppBar
        ),
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
                'Módulos:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 10), // Espaço entre o texto e os botões
              Wrap( // Usando Wrap para melhor responsividade
                spacing: 12.0, // Espaço horizontal entre os botões
                runSpacing: 12.0, // Espaço vertical entre as linhas de botões
                alignment: WrapAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PacientesPage()));
                    },
                    child: const Text('Pacientes'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const Sessoes()));
                    },
                    child: const Text('Sessões'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendaSemanalPage()));
                    },
                    child: const Text('Agenda'),
                  ),
                  // --- NOVO BOTÃO ADICIONADO AQUI ---
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaEsperaPage()));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
                    child: const Text('Lista Espera'),
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