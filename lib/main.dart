import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';

// --- הגדרות עיצוב ---
final List<Map<String, dynamic>> avatarsList = [
  {"icon": Icons.face, "color": Colors.blue},
  {"icon": Icons.emoji_emotions, "color": Colors.orange},
  {"icon": Icons.pets, "color": Colors.brown},
  {"icon": Icons.android, "color": Colors.green},
  {"icon": Icons.sentiment_very_satisfied, "color": Colors.purple},
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    theme: ThemeData(
      primaryColor: const Color(0xFF2E7D32),
      fontFamily: 'Arial',
    ),
    home: const SplashScreen(),
  ));
}

// ==================== מסך 1: ספלאש ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyAwcowwITIrOF34LMI2ZO5MfvGaLQ9ui9k",
          appId: "1:117763386132:web:a2a27535872b1b89097001",
          messagingSenderId: "117763386132",
          projectId: "yanivformyfriends",
          databaseURL: "https://yanivformyfriends-default-rtdb.firebaseio.com",
        ),
      );
    } catch (e) {
      print("Error: $e");
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserSetupScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)]
              ),
              child: const Icon(Icons.style, size: 80, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 30),
            const Text("יניב אונליין", style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(3, 3))])),
          ],
        ),
      ),
    );
  }
}

// ==================== מסך 2: יצירת/הצטרפות לשולחן ====================
class UserSetupScreen extends StatefulWidget {
  final String? errorMessage;
  const UserSetupScreen({super.key, this.errorMessage});

  @override
  State<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<UserSetupScreen> {
  String _nickname = "";
  int _selectedAvatarIndex = -1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("הודעת מערכת"),
            content: Text(widget.errorMessage!),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("הבנתי"))],
          ),
        );
      });
    }
  }

  Future<void> _createTable() async {
    setState(() => _isLoading = true);
    String tableCode = (Random().nextInt(9000) + 1000).toString();
    DatabaseReference tableRef = FirebaseDatabase.instance.ref("tables/$tableCode");
    String myPlayerId = tableRef.child("players").push().key!;
    
    await tableRef.update({
      "createdAt": DateTime.now().toIso8601String(),
      "hostId": myPlayerId,
      "currentTurn": "",
      "state": "waiting",
    });

    await _addMeToTable(tableCode, myPlayerId);
  }

  Future<void> _joinExistingTable() async {
    String? codeInput = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = "";
        return AlertDialog(
          title: const Text("הצטרפות לשולחן"),
          content: TextField(
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: "הכנס קוד שולחן (4 ספרות)"),
            onChanged: (val) => input = val,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("ביטול")),
            ElevatedButton(onPressed: () => Navigator.pop(context, input), child: const Text("הכנס")),
          ],
        );
      }
    );

    if (codeInput != null && codeInput.length == 4) {
      setState(() => _isLoading = true);
      final snapshot = await FirebaseDatabase.instance.ref("tables/$codeInput").get();
      if (snapshot.exists) {
        String myPlayerId = FirebaseDatabase.instance.ref("tables/$codeInput/players").push().key!;
        await _addMeToTable(codeInput, myPlayerId);
      } else {
        setState(() => _isLoading = false);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("לא מצאנו שולחן עם הקוד הזה :/")));
      }
    }
  }

  Future<void> _addMeToTable(String tableCode, String myPlayerId) async {
    DatabaseReference playerRef = FirebaseDatabase.instance.ref("tables/$tableCode/players/$myPlayerId");
    await playerRef.onDisconnect().remove();
    await playerRef.set({
      "name": _nickname,
      "avatarIndex": _selectedAvatarIndex,
      "joinedAt": DateTime.now().toIso8601String(),
      "isReady": false,
      "score": 0,
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => YanivTable(myPlayerId: myPlayerId, tableCode: tableCode)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canProceed = _nickname.isNotEmpty && _selectedAvatarIndex != -1;
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              children: [
                const Text("ברוכים הבאים!", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("בחרו שם ודמות כדי להתחיל", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                TextField(
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(hintText: "הכנס כינוי...", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                  onChanged: (value) => setState(() => _nickname = value),
                ),
                const SizedBox(height: 30),
                Wrap(
                  spacing: 15, runSpacing: 15, alignment: WrapAlignment.center,
                  children: List.generate(avatarsList.length, (index) {
                    bool isSelected = _selectedAvatarIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatarIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? avatarsList[index]['color'].withOpacity(0.2) : Colors.white,
                          border: Border.all(color: isSelected ? avatarsList[index]['color'] : Colors.grey.shade300, width: isSelected ? 3 : 1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(avatarsList[index]['icon'], size: 40, color: isSelected ? avatarsList[index]['color'] : Colors.grey),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 50),
                if (_isLoading)
                  const CircularProgressIndicator()
                else 
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton.icon(
                          onPressed: canProceed ? _createTable : null,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text("צור שולחן חדש", style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text("- או -", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: OutlinedButton.icon(
                          onPressed: canProceed ? _joinExistingTable : null,
                          icon: const Icon(Icons.login),
                          label: const Text("הצטרף לשולחן קיים", style: TextStyle(fontSize: 18)),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2E7D32), side: const BorderSide(color: Color(0xFF2E7D32), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== מסך 3: שולחן המשחק ====================
class YanivTable extends StatefulWidget {
  final String myPlayerId; 
  final String tableCode; 

  const YanivTable({super.key, required this.myPlayerId, required this.tableCode});

  @override
  State<YanivTable> createState() => _YanivTableState();
}

class _YanivTableState extends State<YanivTable> {
  // נתונים כלליים
  List<Map<String, dynamic>> _activePlayers = [];
  String _hostId = ""; 
  String _currentTurnId = ""; 
  final int maxScore = 100; 
  String _gameStatusMessage = "";
  Timer? _inactivityTimer;
  bool _amIReady = false;

  // נתוני יד ומשחק
  List<Map<dynamic, dynamic>> _myHand = [];
  List<Map<dynamic, dynamic>> _visibleHand = []; // היד שלי
  List<Map<dynamic, dynamic>> _discardPile = []; // הקלפים הפתוחים על השולחן
  
  List<int> _selectedCardsIndices = []; // בחירה לזריקה
  
  // שלב התור: 'throw' (לזרוק קלפים) -> 'pickup' (לקחת קלף)
  String _turnPhase = 'throw'; // ברירת מחדל: מתחילים בזריקה

  @override
  void initState() {
    super.initState();
    _fetchHostId(); 
    _listenToPlayers();
    _listenToTurn(); 
    _listenToMyHand();
    _listenToDiscardPile();
    _startInactivityTimer();
  }

  void _fetchHostId() {
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/hostId").get().then((snapshot) {
      if (snapshot.exists) setState(() => _hostId = snapshot.value.toString());
    });
  }

  void _listenToTurn() {
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/currentTurn").onValue.listen((event) {
      if (mounted) {
        String newTurn = event.snapshot.value?.toString() ?? "";
        // אם התור עבר למישהו אחר (או אליי), נאפס מצב
        setState(() {
          _currentTurnId = newTurn;
          if (newTurn == widget.myPlayerId) {
            _turnPhase = 'throw'; // תחילת תור - קודם כל זורקים!
            _selectedCardsIndices.clear();
          }
        });
      }
    });
  }

  void _listenToDiscardPile() {
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/discardPile").onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<dynamic, dynamic>> pile = [];
      if (data != null) {
        for (var card in (data as List)) {
          if (card != null) pile.add(card as Map<dynamic, dynamic>);
        }
      }
      if (mounted) setState(() => _discardPile = pile);
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 2), () {
      if (!_amIReady) {
        _autoKickMe();
      }
    });
  }

  void _autoKickMe() {
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players/${widget.myPlayerId}").remove();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserSetupScreen(errorMessage: "הוסרת מהשולחן עקב חוסר פעילות.")));
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _listenToPlayers() {
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players").onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) {
        if (mounted) setState(() => _activePlayers = []);
        return;
      }
      Map<dynamic, dynamic> playersMap = data as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> tempList = [];
      playersMap.forEach((key, value) {
        tempList.add({
          "id": key,
          "name": value['name'],
          "avatarIndex": value['avatarIndex'],
          "joinedAt": value['joinedAt'] ?? "",
          "isReady": value['isReady'] ?? false,
          "score": value['score'] ?? 0, 
        });
      });
      tempList.sort((a, b) => a['joinedAt'].compareTo(b['joinedAt']));

      if (mounted) {
        setState(() {
          _activePlayers = tempList;
          var me = tempList.firstWhere((p) => p['id'] == widget.myPlayerId, orElse: () => {});
          if (me.isNotEmpty) {
            _amIReady = me['isReady'];
          } else {
             _inactivityTimer?.cancel();
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserSetupScreen(errorMessage: "יצאת מהשולחן.")));
          }
        });
      }
      _checkIfAllReadyAndDeal(tempList);
      _checkWinner(tempList); 
    });
  }

  void _leaveGame() {
    _inactivityTimer?.cancel();
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players/${widget.myPlayerId}").remove();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserSetupScreen()));
  }
  
  void _kickPlayer(String playerIdToKick) {
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players/$playerIdToKick").remove();
  }

  void _checkWinner(List<Map<String, dynamic>> players) {
    for (var p in players) {
      if (p['score'] > maxScore) {
        var winner = players.reduce((curr, next) => curr['score'] < next['score'] ? curr : next);
        if (mounted) {
           showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("המשחק נגמר!", textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${p['name']} עבר את ה-$maxScore נקודות!"),
                  const SizedBox(height: 20),
                  const Icon(Icons.emoji_events, size: 50, color: Colors.amber),
                  const SizedBox(height: 10),
                  Text("המנצח הוא: ${winner['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text("עם ${winner['score']} נקודות בלבד"),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("סגור"))],
            ),
          );
        }
        break; 
      }
    }
  }

  // --- לוגיקת קלפים ואנימציה ---
  void _listenToMyHand() {
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players/${widget.myPlayerId}/hand").onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<dynamic, dynamic>> tempHand = [];
      if (data != null) {
        for (var card in (data as List)) {
          if (card != null) tempHand.add(card as Map<dynamic, dynamic>);
        }
      }
      
      bool isNewDeal = _myHand.isEmpty && tempHand.isNotEmpty;
      if (mounted) setState(() => _myHand = tempHand);
      if (isNewDeal) {
        _animateDealing(tempHand);
      } else if (tempHand.length != _visibleHand.length) {
         if (mounted) setState(() => _visibleHand = List.from(tempHand));
      }
    });
  }

  Future<void> _animateDealing(List<Map<dynamic, dynamic>> fullHand) async {
    setState(() => _visibleHand = []);
    for (var card in fullHand) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _visibleHand.add(card);
        });
      }
    }
  }

  void _setReady() {
    _inactivityTimer?.cancel(); 
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players/${widget.myPlayerId}").update({"isReady": true});
  }

  void _checkIfAllReadyAndDeal(List<Map<String, dynamic>> players) {
    if (players.isEmpty) return;
    if (players.length < 2) {
      if (mounted && _gameStatusMessage != "ממתין לעוד שחקנים...") setState(() => _gameStatusMessage = "צריך לפחות 2 שחקנים כדי להתחיל");
      return; 
    }
    bool allReady = true;
    for (var p in players) {
      if (p['isReady'] == false) allReady = false;
    }
    if (allReady) {
       if (_currentTurnId.isEmpty) {
          if (widget.myPlayerId == _hostId) {
            _dealCards(players);
            String firstPlayerId = players.first['id'];
            FirebaseDatabase.instance.ref("tables/${widget.tableCode}").update({
              "currentTurn": firstPlayerId
            });
          }
       }
       if (mounted) setState(() => _gameStatusMessage = "");
    } else {
      if (mounted) setState(() => _gameStatusMessage = "ממתין שכולם ילחצו מוכן...");
    }
  }

  Future<void> _dealCards(List<Map<String, dynamic>> playersToDeal) async {
    List<String> suits = ["heart", "diamond", "spade", "club"];
    List<String> ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
    List<Map<String, String>> deck = [];
    for (var suit in suits) {
      for (var rank in ranks) deck.add({"rank": rank, "suit": suit});
    }
    deck.add({"rank": "Joker", "suit": "joker"});
    deck.add({"rank": "Joker", "suit": "joker"});
    deck.shuffle();

    DatabaseReference tableRef = FirebaseDatabase.instance.ref("tables/${widget.tableCode}");
    
    for (var player in playersToDeal) {
      List<Map<String, String>> hand = [];
      for (int i = 0; i < 5; i++) {
        if (deck.isNotEmpty) hand.add(deck.removeLast());
      }
      await tableRef.child("players/${player['id']}").update({"hand": hand});
    }
    
    // קלף פותח לקופה הפתוחה
    List<Map<String, String>> initialDiscard = [];
    if (deck.isNotEmpty) {
      initialDiscard.add(deck.removeLast());
    }

    await tableRef.child("discardPile").set(initialDiscard);
    await tableRef.child("stockpile").set(deck);
  }

  // --- פעולות במשחק ---
  
  // 1. בחירת קלפים מהיד לזריקה
  void _toggleCardSelection(int index) {
    // מותר לבחור רק אם תורי ורק אם אני בשלב הזריקה
    if (_currentTurnId != widget.myPlayerId || _turnPhase != 'throw') return;
    setState(() {
      if (_selectedCardsIndices.contains(index)) {
        _selectedCardsIndices.remove(index);
      } else {
        _selectedCardsIndices.add(index);
      }
    });
  }

  // 2. זריקת הקלפים (סיום שלב א', מעבר לשלב ב' - לקיחה)
  Future<void> _throwCards() async {
    if (_selectedCardsIndices.isEmpty) return;
    
    List<Map<dynamic, dynamic>> thrownCards = [];
    List<Map<dynamic, dynamic>> newHand = [];
    
    for (int i = 0; i < _visibleHand.length; i++) {
      if (_selectedCardsIndices.contains(i)) {
        thrownCards.add(_visibleHand[i]);
      } else {
        newHand.add(_visibleHand[i]);
      }
    }
    
    await FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players/${widget.myPlayerId}/hand").set(newHand);
    
    // החלפת הקלפים על השולחן בחדשים
    await FirebaseDatabase.instance.ref("tables/${widget.tableCode}/discardPile").set(thrownCards);
    
    setState(() {
      _selectedCardsIndices.clear();
      _turnPhase = 'pickup'; // עכשיו צריך לקחת
    });
  }

  // 3. לקיחה מהקופה הסגורה (סיום תור)
  Future<void> _drawFromStock() async {
    if (_currentTurnId != widget.myPlayerId || _turnPhase != 'pickup') return;

    DatabaseReference stockpileRef = FirebaseDatabase.instance.ref("tables/${widget.tableCode}/stockpile");
    final snapshot = await stockpileRef.get();
    if (snapshot.exists) {
      List<dynamic> deck = snapshot.value as List<dynamic>;
      if (deck.isNotEmpty) {
        var card = deck.last;
        deck.removeLast(); 
        await stockpileRef.set(deck);
        
        List<Map<dynamic, dynamic>> newHand = List.from(_visibleHand);
        newHand.add(card as Map<dynamic, dynamic>);
        await FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players/${widget.myPlayerId}/hand").set(newHand);
        
        _passTurn();
      }
    }
  }

  // 4. לקיחה מהשולחן (סיום תור)
  Future<void> _pickFromDiscard(int index) async {
    if (_currentTurnId != widget.myPlayerId || _turnPhase != 'pickup') return;

    // חוק: אם יש יותר מקלף אחד, מותר לקחת רק מהקצוות
    if (_discardPile.length > 1) {
      if (index != 0 && index != _discardPile.length - 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("אפשר לקחת רק מהצדדים!", textAlign: TextAlign.center), duration: Duration(seconds: 1)));
        return;
      }
    }

    var card = _discardPile[index];
    
    List<Map<dynamic, dynamic>> newHand = List.from(_visibleHand);
    newHand.add(card);
    await FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players/${widget.myPlayerId}/hand").set(newHand);

    // השולחן מתנקה אחרי שלקחת (כי השאר "מתים")
    await FirebaseDatabase.instance.ref("tables/${widget.tableCode}/discardPile").remove();

    _passTurn();
  }

  void _passTurn() {
    int myIndex = _activePlayers.indexWhere((p) => p['id'] == widget.myPlayerId);
    int nextIndex = (myIndex + 1) % _activePlayers.length; 
    String nextPlayerId = _activePlayers[nextIndex]['id'];
    
    FirebaseDatabase.instance.ref("tables/${widget.tableCode}").update({
      "currentTurn": nextPlayerId
    });
    
    setState(() => _turnPhase = 'throw'); // התור הבא מתחיל שוב בזריקה
  }

  int _calculateCardValue(Map<dynamic, dynamic> card) {
    String rank = card['rank'];
    if (rank == "Joker") return 0;
    if (rank == "A") return 1;
    if (["J", "Q", "K"].contains(rank)) return 10;
    return int.tryParse(rank) ?? 0;
  }

  Future<void> _endRoundAndCalculateScore() async {
    DatabaseReference playersRef = FirebaseDatabase.instance.ref("tables/${widget.tableCode}/players");
    for (var player in _activePlayers) {
      // כאן יבוא חישוב הניקוד המלא בעתיד
      await playersRef.child(player['id']).update({
        "isReady": false, 
        "hand": null 
      });
    }
    await FirebaseDatabase.instance.ref("tables/${widget.tableCode}").update({
      "currentTurn": "",
      "discardPile": null,
      "stockpile": null
    });
  }

  @override
  Widget build(BuildContext context) {
    bool amIHost = widget.myPlayerId == _hostId;
    bool isMyTurn = _currentTurnId == widget.myPlayerId;

    return Scaffold(
      backgroundColor: const Color(0xFF35654d),
      appBar: AppBar(
        backgroundColor: Colors.black26,
        elevation: 0,
        title: Column(
          children: [
            const Text("יניב אונליין", style: TextStyle(fontSize: 14)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("קוד שולחן: ${widget.tableCode}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.tableCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("הקוד הועתק!")));
                  },
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: () {
               _leaveGame();
            },
          ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.yellow, size: 30),
              onPressed: () => Scaffold.of(context).openEndDrawer(), 
            ),
          ),
        ],
      ),
      
      endDrawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF2E7D32)),
              child: Center(child: Text("טבלת ניקוד", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold))),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _activePlayers.length,
                itemBuilder: (context, index) {
                  final p = _activePlayers[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: avatarsList[p['avatarIndex']]['color'], child: Icon(avatarsList[p['avatarIndex']]['icon'], color: Colors.white)),
                    title: Text(p['name']),
                    trailing: Text("${p['score']} נק'", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      
      body: Column(
        children: [
          // רשימת שחקנים (למעלה)
          Container(
            height: 140,
            padding: const EdgeInsets.all(10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _activePlayers.length,
              itemBuilder: (context, index) {
                final player = _activePlayers[index];
                final bool isMe = player['id'] == widget.myPlayerId;
                final bool isReady = player['isReady']; 
                final int avatarIdx = player['avatarIndex'];
                final bool isHisTurn = player['id'] == _currentTurnId;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isHisTurn)
                            Container(width: 66, height: 66, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orangeAccent, width: 3), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)])),
                          CircleAvatar(radius: 30, backgroundColor: isReady ? Colors.green : avatarsList[avatarIdx]['color'], child: Icon(avatarsList[avatarIdx]['icon'], color: Colors.white, size: 30)),
                          if (isReady)
                            const Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.check_circle, color: Colors.green, size: 24))),
                          if (amIHost && !isMe)
                             Positioned(top: 0, right: 0, child: GestureDetector(onTap: () => _kickPlayer(player['id']), child: const CircleAvatar(radius: 10, backgroundColor: Colors.white, child: Icon(Icons.delete, color: Colors.red, size: 16)))),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(isMe ? "${player['name']} (אני)" : player['name'], style: TextStyle(color: isMe ? Colors.yellow : Colors.white, fontWeight: FontWeight.bold)),
                      if (isHisTurn) const Text("תורי!", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const Spacer(), 
          
          // --- אזור השולחן (קופה + קלפים זרוקים) ---
          if (_currentTurnId.isNotEmpty) 
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. קופה סגורה (משמאל)
                GestureDetector(
                  onTap: (isMyTurn && _turnPhase == 'pickup') ? _drawFromStock : null,
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 110,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E), // כחול כהה מאוד (גב הקלף)
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24, width: 2),
                          boxShadow: [
                             if (isMyTurn && _turnPhase == 'pickup')
                               const BoxShadow(color: Colors.yellow, blurRadius: 15, spreadRadius: 2)
                             else
                               const BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(2, 2))
                          ],
                        ),
                        child: Center(child: Icon(Icons.token, color: Colors.white.withOpacity(0.2), size: 40)),
                      ),
                      const SizedBox(height: 5),
                      if (isMyTurn && _turnPhase == 'pickup')
                        const Text("קח מכאן", style: TextStyle(color: Colors.yellow, fontSize: 12))
                    ],
                  ),
                ),

                // 2. קלפים פתוחים (מימין) - הקלפים שנזרקו
                if (_discardPile.isNotEmpty)
                  Column(
                    children: [
                      Container(
                        height: 120,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_discardPile.length, (index) {
                            bool isClickable = (index == 0 || index == _discardPile.length - 1);
                            return GestureDetector(
                              onTap: (isMyTurn && _turnPhase == 'pickup') ? () => _pickFromDiscard(index) : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Transform.scale(
                                  scale: 0.9,
                                  child: Container(
                                    decoration: (isMyTurn && _turnPhase == 'pickup' && isClickable) 
                                      ? BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: [const BoxShadow(color: Colors.yellow, blurRadius: 10, spreadRadius: 1)])
                                      : null,
                                    child: GameCard(
                                      rank: _discardPile[index]['rank'],
                                      suit: _discardPile[index]['suit'],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (isMyTurn && _turnPhase == 'pickup')
                        const Text("או מכאן", style: TextStyle(color: Colors.yellow, fontSize: 12))
                    ],
                  )
                else
                  const SizedBox(width: 80, height: 110, child: Center(child: Text("השולחן ריק", style: TextStyle(color: Colors.white30)))),
              ],
            ),

          const Spacer(),
          
          // --- הודעת סטטוס ---
          if (isMyTurn)
             Padding(
               padding: const EdgeInsets.all(8.0),
               child: Text(
                 _turnPhase == 'throw' ? "בחר קלפים מהיד וזרוק אותם" : "עכשיו קח קלף מהקופה או מהשולחן",
                 style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)
               ),
             ),

          // --- כפתור זריקה ---
          if (isMyTurn && _turnPhase == 'throw' && _selectedCardsIndices.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(bottom: 10),
               child: ElevatedButton.icon(
                 onPressed: _throwCards,
                 icon: const Icon(Icons.delete_sweep),
                 label: const Text("זרוק קלפים", style: TextStyle(fontSize: 18)),
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
               ),
             ),

          // --- אזור היד שלי ---
          if (_visibleHand.isEmpty) ...[
            if (!_amIReady)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _setReady,
                  icon: const Icon(Icons.thumb_up),
                  label: const Text("אני מוכן!"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), textStyle: const TextStyle(fontSize: 22), backgroundColor: Colors.orange),
                ),
              )
            else
              const Center(child: Text("מחכה שכולם יהיו מוכנים...", style: TextStyle(color: Colors.white70, fontSize: 24))),
          ] else ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_visibleHand.length, (index) {
                  bool isSelected = _selectedCardsIndices.contains(index);
                  return GestureDetector(
                    onTap: () => _toggleCardSelection(index),
                    child: Transform.translate(
                      offset: Offset(0, isSelected ? -20 : 0), 
                      child: GameCard(
                        rank: _visibleHand[index]['rank'], 
                        suit: _visibleHand[index]['suit'],
                        isSelected: isSelected, 
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 30),
            
            // כפתור יניב (סיום סיבוב) - רק אם תורי ועדיין לא זרקתי
            if (isMyTurn && _turnPhase == 'throw') 
              ElevatedButton(
                onPressed: _endRoundAndCalculateScore,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12)),
                child: const Text("הכרז יניב!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
          ],
            
          const Spacer(),
        ],
      ),
    );
  }
}

// === כרטיס משחק מעוצב מחדש ===
class GameCard extends StatelessWidget {
  final String rank; 
  final String suit; 
  final bool isSelected; 

  const GameCard({super.key, required this.rank, required this.suit, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    Color suitColor;
    String displaySuit;
    
    if (suit == "joker") {
      suitColor = Colors.purple;
      displaySuit = "🤡"; 
    } else {
      suitColor = (suit == "heart" || suit == "diamond") ? Colors.red[800]! : Colors.black;
      switch (suit) {
        case "heart": displaySuit = "♥"; break; 
        case "diamond": displaySuit = "♦"; break; 
        case "spade": displaySuit = "♠"; break; 
        case "club": displaySuit = "♣"; break; 
        default: displaySuit = "?";
      }
    }

    return Container(
      margin: const EdgeInsets.all(4.0),
      width: 70, height: 105,
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(10), 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(2, 3))
        ],
        border: isSelected 
          ? Border.all(color: Colors.blueAccent, width: 3) 
          : Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4, left: 6,
            child: Text(rank == "Joker" ? "J" : rank, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: suitColor)),
          ),
          Positioned(
            top: 24, left: 6,
            child: Text(displaySuit, style: TextStyle(fontSize: 14, color: suitColor)),
          ),
          Center(
            child: Text(displaySuit, style: TextStyle(fontSize: 38, color: suitColor)),
          ),
          Positioned(
            bottom: 4, right: 6,
            child: Transform.rotate(
              angle: 3.14159,
              child: Text(rank == "Joker" ? "J" : rank, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: suitColor)),
            ),
          ),
        ],
      ),
    );
  }
}