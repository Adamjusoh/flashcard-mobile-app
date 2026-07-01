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
            backgroundColor: Color(0xFF16A34A),
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
            backgroundColor: const Color(0xFFDC2626),
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
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scan Deck QR',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Dark background
          Container(color: const Color(0xFF1E293B)),

          // Center Scanner Box — camera feed restricted to this square
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 260,
              width: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4F46E5), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
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

          // Corner markers for scanner feel
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 270,
              width: 270,
              child: Stack(
                children: [
                  // Top-left corner
                  Positioned(top: 0, left: 0, child: _buildCorner(true, true)),
                  // Top-right corner
                  Positioned(top: 0, right: 0, child: _buildCorner(true, false)),
                  // Bottom-left corner
                  Positioned(bottom: 0, left: 0, child: _buildCorner(false, true)),
                  // Bottom-right corner
                  Positioned(bottom: 0, right: 0, child: _buildCorner(false, false)),
                ],
              ),
            ),
          ),

          // Instruction Text
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 140.0),
              child: Text(
                'Position the QR code within the frame',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Loading Overlay when processing
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      SizedBox(height: 20),
                      Text(
                        'Copying deck...',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}