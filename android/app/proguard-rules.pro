# Keep kotlinx.serialization runtime
-keepclasseswithmembers class **$Companion {
    kotlinx.serialization.KSerializer serializer(...);
}
-if class **$Companion { kotlinx.serialization.KSerializer serializer(...); }
-keepclasseswithmembers class <1> {
    <1>$Companion Companion;
}
-keepnames class agilelens.understudy.** { *; }
