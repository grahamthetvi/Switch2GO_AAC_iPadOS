#!/usr/bin/env ruby
# Script to fix Xcode project references

require 'xcodeproj'

project_path = 'iosApp/iosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
main_group = project.main_group['iosApp']

puts "🔧 Fixing Xcode project references..."

# Remove old incorrect references
puts "Removing old references..."
['Utils', 'Data', 'ViewModels'].each do |folder_name|
  if group = main_group[folder_name]
    # Check if path is wrong (iosApp/Utils instead of iosApp/iosApp/Utils)
    if group.real_path.to_s.include?('iosApp/Utils') && !group.real_path.to_s.include?('iosApp/iosApp/Utils')
      puts "  Removing incorrect #{folder_name}/"
      group.remove_from_project
    end
  end
end

# Function to add files recursively
def add_files_recursively(project, group, folder_path, target)
  Dir.foreach(folder_path) do |entry|
    next if entry == '.' || entry == '..'
    
    full_path = File.join(folder_path, entry)
    
    if File.directory?(full_path)
      # Create group for subdirectory
      subgroup = group.new_group(entry, entry)
      add_files_recursively(project, subgroup, full_path, target)
    elsif entry.end_with?('.swift')
      # Add Swift file
      file_ref = group.new_file(full_path)
      target.add_file_references([file_ref])
      puts "  Added: #{entry}"
    elsif entry.end_with?('.strings')
      # Add strings file to resources
      file_ref = group.new_file(full_path)
      target.resources_build_phase.add_file_reference(file_ref)
      puts "  Added resource: #{entry}"
    end
  end
end

# Add correct references
puts "\nAdding correct references..."

# Add Utils
if !main_group['Utils']
  utils_group = main_group.new_group('Utils', 'iosApp/Utils')
  add_files_recursively(project, utils_group, 'iosApp/iosApp/Utils', target)
end

# Add Data
if !main_group['Data']
  data_group = main_group.new_group('Data', 'iosApp/Data')
  add_files_recursively(project, data_group, 'iosApp/iosApp/Data', target)
end

# Add ViewModels
if !main_group['ViewModels']
  vm_group = main_group.new_group('ViewModels', 'iosApp/ViewModels')
  add_files_recursively(project, vm_group, 'iosApp/iosApp/ViewModels', target)
end

# Save project
project.save

puts "\n✅ Xcode project references fixed!"
puts "Now in Xcode: Cmd+Shift+K (Clean) then Cmd+B (Build)"
