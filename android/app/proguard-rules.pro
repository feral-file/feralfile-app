-keep class com.bitmark.autonomy_flutter.** { *; }
-keep class it.airgap.beaconsdk.** { *; }

# Keep `Companion` object fields of serializable classes.
# This avoids serializer lookup through `getDeclaredClasses` as done for named companion objects.
-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}

# Keep `serializer()` on companion objects (both default and named) of serializable classes.
-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep `INSTANCE.serializer()` of serializable objects.
-if @kotlinx.serialization.Serializable class ** {
    public static ** INSTANCE;
}
-keepclassmembers class <1> {
    public static <1> INSTANCE;
    kotlinx.serialization.KSerializer serializer(...);
}

# @Serializable and @Polymorphic are used at runtime for polymorphic serialization.
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault

# Serializer for classes with named companion objects are retrieved using `getDeclaredClasses`.
# If you have any, uncomment and replace classes with those containing named companion objects.
-keepattributes InnerClasses # Needed for `getDeclaredClasses`.
-if @kotlinx.serialization.Serializable class
com.bitmark.autonomy_flutter.**
{
    static **$* *;
}
-keepnames class <1>$$serializer { # -keepnames suffices; class is kept when serializer() is kept.
    static <1>$$serializer INSTANCE;
}

# https://help.branch.io/developers-hub/docs/android-basic-integration
-keep class com.google.android.gms.** { *; }
-keep class com.walletconnect.** { *; }
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keep class **BackgroundFetchHeadlessTask { *; }
-keep class com.pauldemarco.flutter_blue.** { *; }
-keep class com.google.protobuf.** { *; }

#After update AGP to 8.14 and Target SDK to 34, the following rules are required to avoid build errors
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.protobuf.AbstractMessage$Builder
-dontwarn com.google.protobuf.AbstractMessage$BuilderParent
-dontwarn com.google.protobuf.AbstractMessage
-dontwarn com.google.protobuf.Descriptors$Descriptor
-dontwarn com.google.protobuf.Descriptors$EnumDescriptor
-dontwarn com.google.protobuf.Descriptors$EnumValueDescriptor
-dontwarn com.google.protobuf.Descriptors$FieldDescriptor
-dontwarn com.google.protobuf.Descriptors$FileDescriptor
-dontwarn com.google.protobuf.Descriptors$OneofDescriptor
-dontwarn com.google.protobuf.ExtensionRegistry
-dontwarn com.google.protobuf.GeneratedMessageV3$Builder
-dontwarn com.google.protobuf.GeneratedMessageV3$BuilderParent
-dontwarn com.google.protobuf.GeneratedMessageV3$FieldAccessorTable
-dontwarn com.google.protobuf.GeneratedMessageV3$UnusedPrivateParameter
-dontwarn com.google.protobuf.GeneratedMessageV3
-dontwarn com.google.protobuf.MapEntry$Builder
-dontwarn com.google.protobuf.MapEntry
-dontwarn com.google.protobuf.MapField
-dontwarn com.google.protobuf.Message$Builder
-dontwarn com.google.protobuf.Message
-dontwarn com.google.protobuf.MessageOrBuilder
-dontwarn com.google.protobuf.ProtocolMessageEnum
-dontwarn com.google.protobuf.RepeatedFieldBuilderV3
-dontwarn com.google.protobuf.SingleFieldBuilderV3
-dontwarn com.google.protobuf.UnknownFieldSet$Builder
-dontwarn com.google.protobuf.UnknownFieldSet
-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.impl.StaticMDCBinder