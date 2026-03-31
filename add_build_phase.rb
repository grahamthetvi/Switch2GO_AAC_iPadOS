require 'xcodeproj'

project_path = '/Users/user289033/Switch2GO_AAC_iPadOS/iosApp/iosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'iosApp' }

phase_name = 'Build Kotlin Framework'

# Remove existing if any
existing = target.shell_script_build_phases.find { |p| p.name == phase_name }
if existing
  target.build_phases.delete(existing)
end

phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
phase.name = phase_name
phase.shell_script = <<-SCRIPT
cd "$SRCROOT/.."

KOTLIN_CONFIG="Debug"
if [ "$CONFIGURATION" = "Release" ]; then
    KOTLIN_CONFIG="Release"
fi

TARGET="IosArm64"
if [ "$PLATFORM_NAME" = "iphonesimulator" ]; then
    if [[ "$ARCHS" == *"x86_64"* ]]; then
        TARGET="IosX64"
    else
        TARGET="IosSimulatorArm64"
    fi
fi

./gradlew :shared:link${KOTLIN_CONFIG}Framework${TARGET}
SCRIPT

# Insert at the beginning so it runs before compiling Swift code
target.build_phases.insert(0, phase)
project.save

puts "Successfully added build phase"
