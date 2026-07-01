import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _processScannedDeck(String scannedDeckId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestore = FirebaseFirestore.instance;

    try {
      final originalDeckDoc = await firestore.collection('decks').doc(scannedDeckId).get();

      if (!originalDeckDoc.exists) {
        throw Exception("Deck not found or has been deleted.");
      }

      final originalCardsSnapshot = await firestore
          .collection('decks')
          .doc(scannedDeckId)
          .collection('cards')
          .get();

      // Fetch the sharer's username for attribution
      final String authorId = originalDeckDoc.data()?['authorId'] ?? '';
      String sharerUsername = '';
      if (authorId.isNotEmpty) {
        try {
          final userDoc = await firestore.collection('users').doc(authorId).get();
          sharerUsername = userDoc.data()?['username'] as String? ?? '';
        } catch (_) {}
      }

      final originalTitle = originalDeckDoc.data()?['title'] ?? 'Deck';
      final copiedTitle = sharerUsername.isNotEmpty
          ? '$originalTitle (Shared from $sharerUsername)'
          : '$originalTitle (Copy)';

      final batch = firestore.batch();
      final newDeckRef = firestore.collection('decks').doc();

      batch.set(newDeckRef, {
        'title': copiedTitle,
        'authorId': currentUserId,
        'isPublic': false,
        'createdAt': Timestamp.now(),
      });

      for (var cardDoc in originalCardsSnapshot.docs) {
        final newCardRef = newDeckRef.collection('cards').doc();
        final cardData = cardDoc.data();

        batch.set(newCardRef, {
          'front': cardData['front'],
          'back': cardData['back'],
          'interval': 0,
          'repetitions': 0,
          'easeFactor': 2.5,
          'nextReviewDate': Timestamp.now(),
        });
      }

      await batch.commit();

      _cameraController.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deck successfully copied to your library!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy deck: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan Community Deck',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
        ),
      ),
      body: Container(
        // Pure gradient background replacing the full-screen camera image
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A7B9B), Color(0xFF3F9363)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Center Scanner Box - The camera feed is restricted ONLY to this square
            Align(
              alignment: Alignment.center,
              child: Container(
                height: 250,
                width: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1BFFFF), width: 3),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1BFFFF).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    controller: _cameraController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null && !_isProcessing) {
                          _processScannedDeck(barcode.rawValue!);
                        }
                      }
                    },
                  ),
                ),
              ),
            ),

            // Instruction Text
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 150.0), // Lifted slightly above the pill bar
                child: Text(
                  'Position the QR code within the frame.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Loading Overlay (Glassmorphism) when processing
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 150,
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF1BFFFF)),
                            SizedBox(height: 20),
                            Text(
                              'Duplicating Deck...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}