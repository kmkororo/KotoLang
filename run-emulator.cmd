@echo off
rem Boots the KotoLang Android emulator (Android 16 / API 36).
set ANDROID_HOME=C:\Android\Sdk
set ANDROID_SDK_ROOT=C:\Android\Sdk
set JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot
"%ANDROID_HOME%\emulator\emulator.exe" -avd kotolang_api36 -gpu swiftshader_indirect
