import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agenda_treinamento_web/services/firestore_service.dart';
import 'pacientes.dart'; 
import 'cadastro_agenda.dart'; 
import 'sessoes.dart'; 
import 'lista_espera.dart'; 
import 'controle_pagamentos.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FirestoreService _firestoreService = FirestoreService();

  late Future<int> _sessoesHojeFuture;
  late Future<double> _pagamentosPendentesFuture;
  late Future<String> _proximaVagaFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _sessoesHojeFuture = _firestoreService.getSessoesHojeCount();
    _pagamentosPendentesFuture = _firestoreService.getPagamentosPendentesMes();
    _proximaVagaFuture = _firestoreService.getProximaVagaDisponivel();
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0), 
        child: AppBar(
          title: const Text('Painel de Controle'),
          centerTitle: true,
          backgroundColor: Colors.blue, 
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
              tooltip: 'Atualizar Dados',
            )
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(12.0),
          children: [
            _buildResumoSection(),
            const SizedBox(height: 20),
            _buildMenuSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Resumo do Dia",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        // =======================================================================
        // CORREÇÃO: Usando IntrinsicHeight para igualar a altura dos cards
        // =======================================================================
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Faz os filhos esticarem
            children: [
              Expanded(child: _buildResumoCard(
                future: _sessoesHojeFuture,
                icon: Icons.calendar_today,
                label: "Sessões Hoje",
                color: Colors.blue,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildResumoCard(
                future: _pagamentosPendentesFuture,
                icon: Icons.attach_money,
                label: "Pendências do Mês",
                isCurrency: true,
                color: Colors.orange,
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildResumoCard(
          future: _proximaVagaFuture,
          icon: Icons.event_available,
          label: "Próxima Vaga Disponível",
          isText: true,
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildResumoCard({
    required Future future,
    required IconData icon,
    required String label,
    required Color color,
    bool isCurrency = false,
    bool isText = false,
  }) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
                }
                if (snapshot.hasError) {
                  return const Text("Erro", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red));
                }
                
                String value = "N/A";
                if(snapshot.hasData) {
                  if(isCurrency) {
                    value = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(snapshot.data);
                  } else if (isText) {
                    value = snapshot.data.toString();
                  } else {
                    value = snapshot.data.toString();
                  }
                }

                return Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Módulos",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMenuCard(
              icon: Icons.people,
              label: "Pacientes",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PacientesPage())),
            ),
            _buildMenuCard(
              icon: Icons.event_note,
              label: "Sessões",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Sessoes())),
            ),
            _buildMenuCard(
              icon: Icons.schedule,
              label: "Agenda",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendaSemanalPage())),
            ),
            _buildMenuCard(
              icon: Icons.list_alt,
              label: "Lista de Espera",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaEsperaPage())),
            ),
             _buildMenuCard(
              icon: Icons.paid,
              label: "Pagamentos",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ControlePagamentosPage())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}