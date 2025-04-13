// HomePage.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:virtual_assistant/feature_box.dart';
import 'package:virtual_assistant/pallete.dart';
import 'package:virtual_assistant/profile_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const HomePage({super.key, required this.toggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  bool _isRunning = false;
  String _userInput = '';

  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    await _speechToText.initialize();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) => debugPrint('Status: $status'),
        onError: (error) => debugPrint('Error: $error'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
              _userInput = result.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  Future<void> _sendToGemini(String prompt) async {
    const apiKey = 'AIzaSyCh5Tg7llyU2mrkfFf7DR5xWm-v6zGVvK0';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    if (prompt.trim().isEmpty) return;

    setState(() => _isRunning = true);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'] ?? '';

        setState(() {
          _chatHistory.add({
            'type': 'user',
            'text': prompt,
            'time': DateFormat('hh:mm a').format(DateTime.now()),
          });
          _chatHistory.add({
            'type': 'ai',
            'text': responseText,
            'time': DateFormat('hh:mm a').format(DateTime.now()),
          });
        });
      } else {
        debugPrint('Gemini API Error: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch response from Gemini")),
        );
      }
    } catch (e) {
      debugPrint("Gemini Request Error: $e");
    } finally {
      setState(() => _isRunning = false);
    }
  }

  List<Widget> _buildResponseWidgets(String response, ThemeData theme) {
    final List<Widget> widgets = [];
    final codeRegExp = RegExp(r'```(.*?)```', dotAll: true);
    int lastMatchEnd = 0;

    for (final match in codeRegExp.allMatches(response)) {
      final beforeText = response.substring(lastMatchEnd, match.start).trim();
      if (beforeText.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(beforeText, style: TextStyle(fontSize: 16)),
          ),
        );
      }

      final code = match.group(1)?.trim() ?? '';
      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.8),
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  code,
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Code copied to clipboard")),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    final remainingText = response.substring(lastMatchEnd).trim();
    if (remainingText.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(remainingText, style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return widgets;
  }

  void _resetConversation() {
    setState(() {
      _controller.clear();
      _userInput = '';
      _chatHistory.clear();
    });
  }

  Widget _buildChatHistory(ThemeData theme) {
    return Column(
      children:
          _chatHistory.map((entry) {
            final isUser = entry['type'] == 'user';
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color:
                      isUser
                          ? Colors.blueAccent.withOpacity(0.2)
                          : theme.cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildResponseWidgets(entry['text']!, theme),
                    Text(
                      entry['time'] ?? '',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 120,
                  width: 120,
                  decoration: const BoxDecoration(
                    color: Pallete.assistantCircleColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const CircleAvatar(
                  radius: 55,
                  backgroundImage: AssetImage(
                    "assets/images/virtualAssistant.png",
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "Enter your coding query...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onChanged: (val) => _userInput = val,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _isRunning ? null : () => _sendToGemini(_userInput),
                  icon: Icon(_isRunning ? Icons.hourglass_top : Icons.send),
                  label: Text(_isRunning ? "Loading..." : "Ask AI"),
                ),
              ),
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                onPressed: _listen,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildChatHistory(theme),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),
          const Text(
            'Here are a few features',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          FeatureBox(
            color: Pallete.firstSuggestionBoxColor,
            headerText: 'Code Generation',
            descriptionText:
                'Generate code based on your queries using Gemini AI.',
          ),
          const SizedBox(height: 10),
          FeatureBox(
            color: Pallete.secondSuggestionBoxColor,
            headerText: 'Error Fixing',
            descriptionText: 'Explain and fix errors in your code snippets.',
          ),
          const SizedBox(height: 10),
          FeatureBox(
            color: Pallete.thirdSuggestionBoxColor,
            headerText: 'Optimization',
            descriptionText: 'Suggest improvements and optimize your code.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text("User not logged in")),
          );
        }

        final user = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Astra'),
            centerTitle: true,
            leading: Builder(
              builder:
                  (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _resetConversation,
              ),
              IconButton(
                icon: Icon(
                  theme.brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: widget.toggleTheme,
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(user.displayName ?? 'No Name'),
                  accountEmail: Text(user.email ?? 'No Email'),
                  currentAccountPicture: CircleAvatar(
                    backgroundImage:
                        user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : const AssetImage(
                                  "assets/images/default_profile.png",
                                )
                                as ImageProvider,
                  ),
                  decoration: const BoxDecoration(
                    color: Pallete.firstSuggestionBoxColor,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('View Profile'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ProfilePage(
                              toggleTheme: () {
                                widget.toggleTheme;
                              },
                            ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
          ),

          body: _buildBody(theme),
        );
      },
    );
  }
}
