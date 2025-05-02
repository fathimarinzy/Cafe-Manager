import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../services/kitchen_print_service.dart';

class KitchenNoteDialog extends StatefulWidget {
  final String initialNote;
  final MenuItem? menuItem; // Pass the menu item for direct printing

  const KitchenNoteDialog({
    super.key,
    this.initialNote = '',
    this.menuItem,
  });

  @override
  State<KitchenNoteDialog> createState() => _KitchenNoteDialogState();
}

class _KitchenNoteDialogState extends State<KitchenNoteDialog> {
  late TextEditingController _noteController;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Clear the note content
  void _clearNote() {
    setState(() {
      _noteController.clear();
    });
  }

  // Extract printing logic to a separate method - direct ESC/POS printing only
  Future<String?> _processNote(BuildContext ctx) async {
    String? noteText = _noteController.text;

    // If we have a menu item, print it to kitchen first
    if (widget.menuItem != null) {
      setState(() {
        _isPrinting = true;
      });
      
      try {
        // Create a temporary copy of the menu item with the current note
        final itemWithNote = widget.menuItem!.copyWith(
          kitchenNote: noteText,
        );
        
        // Print the kitchen ticket using direct ESC/POS commands
        await KitchenPrintService.printKitchenTicket(itemWithNote);
      } catch (e) {
        debugPrint('Error printing kitchen ticket: $e');
        // Continue even if printing fails - note will still be saved
      }
      
      // Check if still mounted before updating state
      if (!mounted) return null;
      
      setState(() {
        _isPrinting = false;
      });
    }

    // Return the note text
    return noteText;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog header with title
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Kitchen note',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Text field for the note
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _noteController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(12),
                  border: InputBorder.none,
                  hintText: 'Enter kitchen note here...',
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side - Remove button
                ElevatedButton.icon(
                  onPressed: _clearNote,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade900,
                  ),
                ),
                
                // Right side actions
                Row(
                  children: [
                    // Cancel button
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, null), // Return null to indicate cancel
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Cancel'),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Add button (now also prints to kitchen)
                    ElevatedButton.icon(
                      onPressed: _isPrinting ? null : () async {
                        // Pass the current context to the processing method
                        final noteText = await _processNote(context);
                        
                        // Perform context-dependent actions after async gap
                        if (!context.mounted) return;
                        
                        // Return the text to save it (even if printing failed)
                        Navigator.pop(context, noteText);
                      },
                      icon: _isPrinting 
                          ? const SizedBox(
                              width: 18, 
                              height: 18, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : const Icon(Icons.check_circle, size: 18),
                      label: Text(_isPrinting ? 'Printing...' : 'Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}