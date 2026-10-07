# Android wiring for the Glance widget (Step 4)

These snippets go into the Flutter app's `android/` project (created by `flutter create`).

## 1. `android/app/build.gradle` — plugins + deps

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "org.jetbrains.kotlin.plugin.serialization" version "1.9.24" // for kotlinx.serialization
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace = "com.scorecast.app"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.scorecast.app"
        minSdk = 26          // Glance needs 23+; 26 for widget features we use
        targetSdk = 34
    }
    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
}

dependencies {
    implementation "androidx.glance:glance-appwidget:1.1.1"
    implementation "androidx.glance:glance-material3:1.1.1"
    implementation "org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3"
    // home_widget (incl. its Glance state classes) comes via the Flutter plugin.
}
```

## 2. `android/app/src/main/AndroidManifest.xml` — register the receiver

Inside `<application>`:

```xml
<receiver
    android:name=".ScoreCastWidgetReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/scorecast_widget_info" />
</receiver>
```

> The deep-link `<intent-filter>` on MainActivity (for `app://match/{id}`) and the
> FCM service go in **Step 5**, alongside the WorkManager + notification setup.

## 3. Kotlin source location

Put the `.kt` files under:
`android/app/src/main/kotlin/com/scorecast/app/`

(the same package as `applicationId`, matching the receiver's qualified name).

## Honest status

I can't run a Gradle/Android build in this chat. Pin `glance`, `kotlin`, and the
Compose compiler extension to a mutually-compatible set for your Kotlin version
(`./gradlew :app:dependencies` will flag conflicts). The widget logic itself is the
reviewable part; versions are the thing most likely to need a nudge.
```
