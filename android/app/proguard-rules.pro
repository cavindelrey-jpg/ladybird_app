# Firebase / Play Services use reflection in a few spots (Firestore's
# POJO (de)serialization, Crashlytics' native symbol upload hooks); R8
# can't see those call sites statically, so keep the classes it would
# otherwise strip or rename.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# cloud_firestore maps Dart objects through Map<String,Object>, not
# custom POJOs, so no @Keep model classes needed beyond the above.

# video_player / pdfx / flutter_quill ship pure-Dart plugin code; their
# thin Android platform-channel shims don't use reflection and need no
# extra rules beyond Flutter's own (auto-merged by the Flutter Gradle
# plugin).
