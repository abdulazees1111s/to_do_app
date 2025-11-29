import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class Task {
  final int id;
  String title;
  bool done;

  Task({required this.id, required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  static Task fromJson(Map<String, dynamic> json) =>
      Task(id: json['id'], title: json['title'], done: json['done']);
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      themeMode: _mode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: TodoListScreen(
        isDark: _mode == ThemeMode.dark,
        toggleTheme: () {
          setState(() {
            _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          });
        },
      ),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;

  TodoListScreen({required this.isDark, required this.toggleTheme});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<Task> _tasks = [];
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  // ----------------- PERSISTENCE --------------------

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _tasks.map((task) => task.toJson()).toList();
    prefs.setString('tasks', jsonEncode(jsonList));
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('tasks');

    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _tasks = decoded.map((e) => Task.fromJson(e)).toList();
      });
    }
  }

  // ----------------- CORE APP LOGIC --------------------

  void _addTask() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.add(Task(id: DateTime.now().millisecondsSinceEpoch, title: text));
    });

    _addController.clear();
    saveTasks();
  }

  void _toggleDone(int index) {
    setState(() {
      _tasks[index].done = !_tasks[index].done;
    });
    saveTasks();
  }

  void _removeTask(int index) {
    final removed = _tasks[index];

    setState(() {
      _tasks.removeAt(index);
    });

    saveTasks();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Deleted '${removed.title}'"),
        action: SnackBarAction(
          label: "Undo",
          onPressed: () {
            setState(() {
              _tasks.insert(index, removed);
            });
            saveTasks();
          },
        ),
      ),
    );
  }

  void _openEditPopup(int index) {
    final controller = TextEditingController(text: _tasks[index].title);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Task"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Edit task",
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text("Save"),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _tasks[index].title = controller.text.trim();
                  });
                  saveTasks();
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, item);
    });
    saveTasks();
  }

  // ------------------- UI ---------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Todo List"),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Column(
        children: [
          // Add input section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: InputDecoration(
                      labelText: "Add a task",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(child: Text("Add"), onPressed: _addTask),
              ],
            ),
          ),

          Expanded(
            child: ReorderableListView.builder(
              onReorder: _onReorder,
              buildDefaultDragHandles: false,
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];

                return Dismissible(
                  key: ValueKey(task.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    color: Colors.red,
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _removeTask(index),
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_handle),
                      ),
                      title: GestureDetector(
                        onTap: () => _openEditPopup(index),
                        child: AnimatedDefaultTextStyle(
                          duration: Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface, // <-- automatically white in dark mode
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          child: Text(task.title),
                        ),
                      ),
                      trailing: Checkbox(
                        value: task.done,
                        onChanged: (_) => _toggleDone(index),
                      ),
                      onTap: () => _openEditPopup(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
