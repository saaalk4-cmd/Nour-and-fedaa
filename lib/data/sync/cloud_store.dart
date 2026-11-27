import 'package:cloud_firestore/cloud_firestore.dart';

/// التخزين السحابي لبيانات الأسرة. كل ولي أمر تحت parents/{uid} فقط
/// (انظر firestore.rules).
abstract class CloudStore {
  Future<List<Map<String, dynamic>>> loadChildren(String uid);
  Future<void> saveChild(String uid, String cloudId, Map<String, dynamic> data);
  Future<void> deleteChild(String uid, String cloudId);
  Future<Map<String, dynamic>?> loadSettings(String uid);
  Future<void> saveSettings(String uid, Map<String, dynamic> data);

  /// يحذف كل بيانات الأسرة من السحابة (عند حذف الحساب).
  Future<void> deleteAll(String uid);
}

class FirestoreCloudStore implements CloudStore {
  FirestoreCloudStore({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _parent(String uid) =>
      _db.collection('parents').doc(uid);

  @override
  Future<List<Map<String, dynamic>>> loadChildren(String uid) async {
    final snap = await _parent(uid).collection('children').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  @override
  Future<void> saveChild(String uid, String cloudId, Map<String, dynamic> data) =>
      _parent(uid).collection('children').doc(cloudId).set({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteChild(String uid, String cloudId) =>
      _parent(uid).collection('children').doc(cloudId).delete();

  @override
  Future<Map<String, dynamic>?> loadSettings(String uid) async =>
      (await _parent(uid).get()).data();

  @override
  Future<void> saveSettings(String uid, Map<String, dynamic> data) =>
      _parent(uid).set(data, SetOptions(merge: true));

  @override
  Future<void> deleteAll(String uid) async {
    final kids = await _parent(uid).collection('children').get();
    final batch = _db.batch();
    for (final d in kids.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_parent(uid));
    await batch.commit();
  }
}

/// تخزين في الذاكرة (للاختبارات).
class MemoryCloudStore implements CloudStore {
  final children = <String, Map<String, Map<String, dynamic>>>{};
  final settings = <String, Map<String, dynamic>>{};

  @override
  Future<List<Map<String, dynamic>>> loadChildren(String uid) async =>
      (children[uid] ?? const {}).values.toList();

  @override
  Future<void> saveChild(String uid, String cloudId, Map<String, dynamic> data) async =>
      (children[uid] ??= {})[cloudId] = Map.of(data);

  @override
  Future<void> deleteChild(String uid, String cloudId) async =>
      children[uid]?.remove(cloudId);

  @override
  Future<Map<String, dynamic>?> loadSettings(String uid) async => settings[uid];

  @override
  Future<void> saveSettings(String uid, Map<String, dynamic> data) async =>
      (settings[uid] ??= {}).addAll(data);

  @override
  Future<void> deleteAll(String uid) async {
    children.remove(uid);
    settings.remove(uid);
  }
}
