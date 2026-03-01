# Java Setup Guide for iOS Build

## 🔧 Quick Fix

If you see: `Unable to locate a Java Runtime`

Run this:
```bash
# If you have Homebrew
brew install openjdk@17

# Then set JAVA_HOME
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

# Verify
java -version
```

---

## 📋 Java Installation Options

### Option 1: Homebrew (Recommended)
```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Java 17
brew install openjdk@17

# Link it
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

# Set JAVA_HOME permanently
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc

# Verify
java -version
```

### Option 2: Oracle JDK
1. Download from: https://www.oracle.com/java/technologies/downloads/
2. Run installer
3. Set JAVA_HOME:
```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
```

### Option 3: Adoptium (Eclipse Temurin)
1. Download from: https://adoptium.net/
2. Install the .pkg file
3. Set JAVA_HOME:
```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
```

---

## 🔍 Verify Installation

```bash
# Check Java version
java -version

# Should show something like:
# openjdk version "17.0.X" ...

# Check JAVA_HOME
echo $JAVA_HOME

# Should show path like:
# /Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home
```

---

## 🚀 Then Build

Once Java is installed:

```bash
# Build iOS framework
./build_ios.sh

# Or manually
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
```

---

## 💡 Troubleshooting

### "command not found: java"
Java isn't in your PATH. Install using one of the methods above.

### "/usr/libexec/java_home" returns error
No Java installed. Use Homebrew method above.

### Wrong Java version (8 or 11)
```bash
# Install Java 17
brew install openjdk@17

# Point to it specifically
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
```

### "Permission denied"
```bash
# Use sudo for system-wide install
sudo brew install openjdk@17
```

---

## 🎯 Why Java 17?

- **Kotlin 2.2.0** requires Java 17+
- **Gradle 8.x** requires Java 17+
- **Android development** uses Java 17
- **Modern tooling** expects Java 17+

Java 17 is the LTS (Long Term Support) version and is the standard for modern Kotlin/Android development.

---

## ✅ Once Java is Ready

Your build script will work:
```bash
./build_ios.sh
```

This will:
1. ✅ Find Java automatically
2. ✅ Build shared framework
3. ✅ Install CocoaPods
4. ✅ Download MediaPipe model
5. ✅ Report success

Then open in Xcode:
```bash
open iosApp/iosApp.xcworkspace
```

---

**Quick Install**: `brew install openjdk@17` 🚀
