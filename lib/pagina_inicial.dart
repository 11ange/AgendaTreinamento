import 'package:flutter/material.dart';
import 'pacientes.dart'; 
import 'cadastro_agenda.dart'; 
import 'sessoes.dart'; 
import 'lista_espera.dart'; 
import 'controle_pagamentos.dart'; // Importe a nova página

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
          backgroundColor: Colors.blue, 
        ),
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16.0), 
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey), 
            borderRadius: BorderRadius.circular(8.0), 
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: <Widget>[
              const Text(
                'Módulos:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 10), 
              Wrap( 
                spacing: 12.0, 
                runSpacing: 12.0, 
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
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaEsperaPage()));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
                    child: const Text('Lista Espera'),
                  ),
                  // --- NOVO BOTÃO DE PAGAMENTOS ---
                   ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ControlePagamentosPage()));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                    child: const Text('Pagamentos'),
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