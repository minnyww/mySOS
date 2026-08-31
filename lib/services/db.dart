import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// MySOS lives in the dedicated `mysosdb` Firestore database (asia-southeast1).
///
/// The project's (default) database sits in a region Eventarc does not
/// support and belongs to another app (trips), so all MySOS data — and the
/// Cloud Functions triggers — are bound to `mysosdb`.
FirebaseFirestore get mysosDb =>
    FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'mysosdb');
