import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/person_provider.dart';

class SearchPersonScreen extends StatefulWidget {
  const SearchPersonScreen({super.key});

  @override
  SearchPersonScreenState createState() => SearchPersonScreenState();
}

class SearchPersonScreenState extends State<SearchPersonScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Load all persons when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PersonProvider>(context, listen: false).loadPersons();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Consumer<PersonProvider>(
              builder: (ctx, personProvider, child) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _isSearching = false;
                              });
                              personProvider.clearSearch();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _isSearching = value.isNotEmpty;
                    });
                    if (_isSearching) {
                      personProvider.searchPersons(value);
                    }
                  },
                );
              },
            ),
          ),
          Expanded(
            child: Consumer<PersonProvider>(
              builder: (ctx, personProvider, child) {
                if (personProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (personProvider.error.isNotEmpty) {
                  return Center(child: Text('Error: ${personProvider.error}'));
                }
                
                final displayList = _isSearching 
                    ? personProvider.searchResults 
                    : personProvider.persons;
                
                if (displayList.isEmpty) {
                  return Center(
                    child: Text(_isSearching
                        ? 'No results found'
                        : 'No people added yet'),
                  );
                }
                
                return ListView.builder(
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final person = displayList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(
                          person.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('📞 ${person.phoneNumber}'),
                            Text('📍 ${person.place}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Visited on', style: TextStyle(fontSize: 12)),
                            Text(
                              DateTime.parse(person.dateVisited).toString().substring(0, 10),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          // You can add details view or edit functionality here
                           // Return the selected person when tapped
                            Navigator.of(context).pop(person);

                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add person screen
          Navigator.of(context).pushNamed('/add-person');
          // When coming back, refresh the list
          Provider.of<PersonProvider>(context, listen: false).loadPersons();
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}