import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:googleapis/drive/v3.dart' as drive;

/// Desktop-compatible Google Drive service using OAuth 2.0
/// Works on Windows, macOS, Linux, Android, and iOS
class DesktopGoogleDriveService {
  // IMPORTANT: Replace these with your actual credentials from Google Cloud Console
  static const String _clientId = '38878128592-s0u58v1khlcu0bjfhqtt4jeele5rfsa2.apps.googleusercontent.com';
  static const String _clientSecret = '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'; // Only needed for desktop
  
  static const String _redirectUri = 'http://localhost:8080'; // For desktop OAuth
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  static HttpServer? _redirectServer;
  static String? _accessToken;
  static String? _refreshToken;
  static DateTime? _tokenExpiry;

  /// Check if we have valid credentials
  static Future<bool> isAuthenticated() async {
    if (_accessToken == null) {
      await _loadTokens();
    }

    if (_accessToken == null) {
      return false;
    }

    // Check if token is expired
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      // Try to refresh
      return await _refreshAccessToken();
    }

    return true;
  }

  /// Authenticate with Google Drive (works on desktop)
  static Future<bool> authenticate() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return await _authenticateDesktop();
      } else {
        // For mobile, you can still use google_sign_in if available
        debugPrint('Mobile authentication - implement your existing google_sign_in flow here');
        return false;
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
      return false;
    }
  }

  /// Desktop authentication using OAuth 2.0 with local redirect server
  static Future<bool> _authenticateDesktop() async {
    try {
      // Start local server to receive OAuth callback
      _redirectServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
      debugPrint('OAuth redirect server started on port 8080');

      // Build authorization URL
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'scope': _scopes.join(' '),
        'access_type': 'offline', // Get refresh token
        'prompt': 'consent', // Force consent to get refresh token
      });

      // Open browser for authentication
      debugPrint('Opening browser for authentication...');
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch URL: $authUrl');
        return false;
      }

      // Wait for callback
      final request = await _redirectServer!.first;
      final queryParams = request.uri.queryParameters;

      // Send response to browser
      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html')
        ..write('<html><body><h1>Authentication successful!</h1><p>You can close this window.</p></body></html>');
      await request.response.close();
      await _redirectServer!.close();
      _redirectServer = null;

      // Check for authorization code
      if (queryParams.containsKey('code')) {
        final code = queryParams['code']!;
        debugPrint('Received authorization code');

        // Exchange code for tokens
        return await _exchangeCodeForTokens(code);
      } else if (queryParams.containsKey('error')) {
        debugPrint('OAuth error: ${queryParams['error']}');
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('Desktop authentication error: $e');
      await _redirectServer?.close();
      _redirectServer = null;
      return false;
    }
  }

  /// Exchange authorization code for access and refresh tokens
  static Future<bool> _exchangeCodeForTokens(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': _redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        
        // Calculate token expiry
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        // Save tokens
        await _saveTokens();

        debugPrint('Successfully obtained tokens');
        return true;
      } else {
        debugPrint('Token exchange failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error exchanging code for tokens: $e');
      return false;
    }
  }

  /// Refresh access token using refresh token
  static Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'refresh_token': _refreshToken,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        await _saveTokens();

        debugPrint('Successfully refreshed access token');
        return true;
      } else {
        debugPrint('Token refresh failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
  }

  /// Save tokens to local storage
  static Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('google_drive_access_token', _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('google_drive_refresh_token', _refreshToken!);
    }
    if (_tokenExpiry != null) {
      await prefs.setString('google_drive_token_expiry', _tokenExpiry!.toIso8601String());
    }
  }

  /// Load tokens from local storage
  static Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('google_drive_access_token');
    _refreshToken = prefs.getString('google_drive_refresh_token');
    
    final expiryStr = prefs.getString('google_drive_token_expiry');
    if (expiryStr != null) {
      _tokenExpiry = DateTime.parse(expiryStr);
    }
  }

  /// Sign out and clear tokens
  static Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_drive_access_token');
    await prefs.remove('google_drive_refresh_token');
    await prefs.remove('google_drive_token_expiry');

    debugPrint('Signed out from Google Drive');
  }

  /// Upload file to Google Drive
  static Future<String?> uploadFile(String filePath, String fileName) async {
    if (!await isAuthenticated()) {
      debugPrint('Not authenticated. Please authenticate first.');
      return null;
    }

    try {
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();

      // Create file metadata
      final metadata = {
        'name': fileName,
        'mimeType': 'application/json',
      };

      // Upload file using multipart request
      final uri = Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers['Authorization'] = 'Bearer $_accessToken';
      request.headers['Content-Type'] = 'multipart/related';

      // Add metadata part
      request.files.add(http.MultipartFile.fromString(
        'metadata',
        jsonEncode(metadata),
        contentType: MediaType('application', 'json'),
      ));

      // Add file content part
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType('application', 'json'),
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final fileId = data['id'];
        debugPrint('File uploaded successfully. File ID: $fileId');
        return fileId;
      } else {
        debugPrint('Upload failed: ${response.statusCode} $responseBody');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  /// List files from Google Drive
  static Future<List<Map<String, dynamic>>> listFiles({String? query}) async {
    if (!await isAuthenticated()) {
      debugPrint('Not authenticated. Please authenticate first.');
      return [];
    }

    try {
      final params = {
        'fields': 'files(id, name, createdTime, modifiedTime, size)',
        'orderBy': 'modifiedTime desc',
      };

      if (query != null) {
        params['q'] = query;
      }

      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', params);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = data['files'] as List;
        
        return files.map((file) => {
          'id': file['id'],
          'name': file['name'],
          'createdTime': file['createdTime'],
          'modifiedTime': file['modifiedTime'],
          'size': file['size'] ?? '0',
        }).toList();
      } else {
        debugPrint('List files failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error listing files: $e');
      return [];
    }
  }

  /// Download file from Google Drive
  static Future<String?> downloadFile(String fileId, String destinationPath) async {
    if (!await isAuthenticated()) {
      debugPrint('Not authenticated. Please authenticate first.');
      return null;
    }

    try {
      final uri = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final file = File(destinationPath);
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('File downloaded successfully to: $destinationPath');
        return destinationPath;
      } else {
        debugPrint('Download failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }

  /// Delete file from Google Drive
  static Future<bool> deleteFile(String fileId) async {
    if (!await isAuthenticated()) {
      debugPrint('Not authenticated. Please authenticate first.');
      return false;
    }

    try {
      final uri = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId');
      final response = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 204) {
        debugPrint('File deleted successfully');
        return true;
      } else {
        debugPrint('Delete failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }
}

/// Widget to test Google Drive authentication
class GoogleDriveAuthButton extends StatefulWidget {
  const GoogleDriveAuthButton({super.key});

  @override
  State<GoogleDriveAuthButton> createState() => _GoogleDriveAuthButtonState();
}

class _GoogleDriveAuthButtonState extends State<GoogleDriveAuthButton> {
  bool _isAuthenticated = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isAuth = await DesktopGoogleDriveService.isAuthenticated();
    setState(() {
      _isAuthenticated = isAuth;
    });
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
    });

    final success = await DesktopGoogleDriveService.authenticate();

    setState(() {
      _isLoading = false;
      _isAuthenticated = success;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Authenticated successfully!' : 'Authentication failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await DesktopGoogleDriveService.signOut();
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_isAuthenticated) {
      return Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          const Text('Connected to Google Drive'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign Out'),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: _authenticate,
      icon: const Icon(Icons.cloud),
      label: const Text('Connect Google Drive'),
    );
  }
}