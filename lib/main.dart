import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importe esta linha
import 'pagina_inicial.dart'; // Importa a página principal
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   // Inicialize os dados de formatação de data para o locale 'pt_BR'
  await initializeDateFormatting('pt_BR', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Fonoaudiologia',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // Inglês
        Locale('pt', 'BR'), // Português do Brasil
        Locale('pt', 'PT'), // Português de Portugal (se você precisar de ambos)
        // Adicione outros idiomas que seu aplicativo suporta
      ],
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0), 
        child: AppBar(
          title: const Text('Agenda de Treinamento'),
          centerTitle: true,
          backgroundColor: Colors.blue, // Cor de fundo da AppBar
        ),
      ),
      body: Center( // Centraliza o conteúdo na tela
        child: Container(
          width: 300, // Defina a largura desejada para o "retângulo"
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey), // Adiciona uma borda cinza
            borderRadius: BorderRadius.circular(8.0), // Opcional: bordas arredondadas
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ajusta a altura da Column ao conteúdo
            children: <Widget>[
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nome de Usuário',
                  border: OutlineInputBorder(), // Opcional: adiciona uma borda ao TextField
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(), // Opcional: adiciona uma borda ao TextField
                ),
              ),
              const SizedBox(height: 15),
              SizedBox( // Envolve o botão para controlar sua largura dentro do Container
                width: double.infinity, // Ocupa a largura total do Container
                child: ElevatedButton(
                  onPressed: () {
                    print('Botão Login clicado!');
                    final username = _usernameController.text;
                    final password = _passwordController.text;

                    if (username == 'teste' && password == 'teste') {
                    //if ((username == 'seu_usuario' && password == 'sua_senha') ||
                    //    (username == 'fono_usuario' && password == 'fono_senha')) {
                      print('Login bem-sucedido para: $username');
                      // Navegar para a MainPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MainPage()),
                      );
                    } else {
                      print('Credenciais inválidas. Tente novamente.');
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MainPage()),
                      );
                    }
                  },
                  child: const Text('Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}