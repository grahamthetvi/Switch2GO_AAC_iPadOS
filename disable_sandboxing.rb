require 'xcodeproj'

project_path = '/Users/user289033/Switch2GO_AAC_iPadOS/iosApp/iosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.build_configurations.each do |config|
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  end
end

project.save

puts "Successfully disabled user script sandboxing"
