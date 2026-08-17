import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): Properties {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(FileInputStream(localPropertiesFile))
    }
    return properties
}

val flutterVersionCode = localProperties().getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties().getProperty("flutter.versionName") ?: "1.0"

// Clé de signature de production, lue dans android/key.properties.
//
// Ce fichier ne doit jamais entrer dans le dépôt : il porte les mots de passe
// du magasin de clés. Il est ignoré par .gitignore, et chaque machine qui
// publie en garde sa propre copie.
val keystoreProperties = Properties()
val keystorePropertiesFile = project.rootProject.file("key.properties")
val keystoreConfigure = keystorePropertiesFile.exists()
if (keystoreConfigure) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.space_learn_flutter"
    compileSdk = 36  
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.example.space_learn_flutter"
        minSdk = 24
        targetSdk = 36
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    signingConfigs {
        if (keystoreConfigure) {
            create("release") {
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // La clé de débogage est la même sur toutes les machines Android,
            // et son mot de passe est public. Un APK signé avec elle peut être
            // décompilé, modifié, re-signé à l'identique : le téléphone du
            // lecteur accepte alors la version trafiquée comme une mise à jour
            // légitime. Google Play refuse d'ailleurs ces paquets.
            //
            // Tant qu'aucune vraie clé n'est fournie on continue de compiler —
            // sinon plus personne ne peut produire d'APK de test — mais on le
            // dit à chaque compilation plutôt que de le laisser passer.
            if (keystoreConfigure) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
                logger.warn(
                    "\n" +
                    "  ⚠  APK DE PRODUCTION SIGNÉ AVEC LA CLÉ DE DÉBOGAGE\n" +
                    "     android/key.properties est absent.\n" +
                    "     Ce paquet ne doit pas être distribué : n'importe qui\n" +
                    "     peut le modifier et le re-signer à l'identique.\n"
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
