import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.codegrove.thebase"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        mainfestPlaceholders = [
            KAKAO_NATIVE_APP_KEY: System.getenv("KAKAO_NATIVE_APP_KEY") ?: ""
        ]
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.codegrove.thebase"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // key.properties 파일에서 정보를 로드합니다.
            val keystoreProperties = Properties()
            // Flutter 프로젝트 루트 디렉토리의 key.properties를 참조합니다.
            val keystorePropertiesFile = rootProject.file("key.properties")

            if (keystorePropertiesFile.exists()) {
                keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }

                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                
                storePassword = keystoreProperties["storePassword"] as String?
            } else {
                println("Error: 'key.properties' file not found in Flutter project root directory. Signing config might be incomplete.")
                throw GradleException("key.properties file not found! Please create it in the project root.")
            }
        }
    }


    buildTypes {
       getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true // 기본값 false => 배포시에는 true로 변경
            isShrinkResources = true // 기본값 false => 배포시에는 true로 변경
             proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
    )
       }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
