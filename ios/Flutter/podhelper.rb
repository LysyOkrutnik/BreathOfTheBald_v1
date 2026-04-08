# This file is part of the Flutter SDK and is used to integrate Flutter with CocoaPods.
# It is normally generated automatically by the 'flutter' command.

def flutter_install_ios_plugin_pods(ios_application_path = nil)
  # Path to the root of the project
  ios_application_path ||= File.dirname(File.realpath(__FILE__))
  
  # Ensure the generated helper script exists
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), ios_application_path)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "Generated.xcconfig not found and required by podhelper.rb. Run 'flutter pub get' on a Mac or CI."
  end

  # Read plugins from .flutter-plugins-dependencies
  plugins_path = File.expand_path(File.join('..', '..', '.flutter-plugins-dependencies'), ios_application_path)
  return unless File.exist?(plugins_path)

  require 'json'
  plugin_deps = JSON.parse(File.read(plugins_path))
  return unless plugin_deps['plugins'] && plugin_deps['plugins']['ios']

  plugin_deps['plugins']['ios'].each do |plugin|
    name = plugin['name']
    path = plugin['path']
    pod name, :path => File.join(path, 'ios')
  end
end

def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_install_ios_plugin_pods(ios_application_path)
end

def flutter_additional_ios_build_settings(target)
  return unless target.respond_to?(:build_configurations)
  target.build_configurations.each do |config|
    # Ensure Bitcode is disabled as Flutter does not support it
    config.build_settings['ENABLE_BITCODE'] = 'NO'
  end
end
