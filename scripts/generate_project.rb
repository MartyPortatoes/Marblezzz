#!/usr/bin/env ruby
# Rebuild the checked-in Xcode project after adding/removing source files.
# Requires the xcodeproj gem; no runtime app dependency.
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.new(File.join(root, 'Marblezzz.xcodeproj'))
project.root_object.attributes['LastUpgradeCheck'] = '2700'
project.root_object.attributes['BuildIndependentTargetsInParallel'] = 'YES'
project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
end

app = project.new_target(:application, 'Marblezzz', :ios, '18.0')
group = project.main_group.new_group('Marblezzz', 'Marblezzz')
Dir.glob(File.join(root, 'Marblezzz', '**', '*.swift')).sort.each do |path|
  reference = group.new_file(path.delete_prefix(File.join(root,'Marblezzz') + '/'))
  app.source_build_phase.add_file_reference(reference)
end
['Resources/Localizable.xcstrings', 'Resources/PrivacyInfo.xcprivacy', 'Resources/Marblezzz.storekit', 'Assets.xcassets'].each do |path|
  app.resources_build_phase.add_file_reference(group.new_file(path))
end
group.new_file('Info.plist'); group.new_file('Marblezzz.entitlements')
local_package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
local_package.relative_path = 'Packages/MarblezzzCore'
project.root_object.package_references << local_package
def add_core(project, target, package)
  product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product.package = package; product.product_name = 'MarblezzzCore'
  target.package_product_dependencies << product
  file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  file.product_ref = product; target.frameworks_build_phase.files << file
end
add_core(project, app, local_package)
app.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.marblezzz.app',
    'INFOPLIST_FILE' => 'Marblezzz/Info.plist',
    'CODE_SIGN_ENTITLEMENTS' => 'Marblezzz/Marblezzz.entitlements',
    'CODE_SIGN_STYLE' => 'Automatic',
    'SWIFT_VERSION' => '6.0',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
    'MARKETING_VERSION' => '1.0',
    'CURRENT_PROJECT_VERSION' => '4',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES'
  })
  config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG' if config.name == 'Debug'
end
tests = project.new_target(:unit_test_bundle, 'MarblezzzTests', :ios, '18.0')
tests.add_dependency(app)
test_group = project.main_group.new_group('MarblezzzTests', 'MarblezzzTests')
Dir.glob(File.join(root,'MarblezzzTests','*.swift')).sort.each { |p| tests.source_build_phase.add_file_reference(test_group.new_file(File.basename(p))) }
tests.resources_build_phase.add_file_reference(group.files.find { |f| f.path == 'Resources/Marblezzz.storekit' })
add_core(project, tests, local_package)
tests.build_configurations.each do |config|
  config.build_settings.merge!({ 'PRODUCT_BUNDLE_IDENTIFIER' => 'com.marblezzz.app.tests', 'GENERATE_INFOPLIST_FILE' => 'YES',
    'SWIFT_VERSION' => '6.0', 'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/Marblezzz.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Marblezzz',
    'BUNDLE_LOADER' => '$(TEST_HOST)', 'TARGETED_DEVICE_FAMILY' => '1,2' })
end
ui = project.new_target(:ui_test_bundle, 'MarblezzzUITests', :ios, '18.0')
ui.add_dependency(app)
ui_group = project.main_group.new_group('MarblezzzUITests', 'MarblezzzUITests')
Dir.glob(File.join(root,'MarblezzzUITests','*.swift')).sort.each { |p| ui.source_build_phase.add_file_reference(ui_group.new_file(File.basename(p))) }
ui.resources_build_phase.add_file_reference(group.files.find { |f| f.path == 'Resources/Marblezzz.storekit' })
ui.build_configurations.each do |config|
  config.build_settings.merge!({ 'PRODUCT_BUNDLE_IDENTIFIER' => 'com.marblezzz.app.uitests', 'GENERATE_INFOPLIST_FILE' => 'YES',
    'SWIFT_VERSION' => '6.0', 'TEST_TARGET_NAME' => 'Marblezzz', 'TARGETED_DEVICE_FAMILY' => '1,2' })
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.add_test_target(ui)
scheme.set_launch_target(app)
scheme.test_action.build_configuration = 'Debug'
scheme.launch_action.build_configuration = 'Debug'
storekit = scheme.launch_action.xml_element.add_element('StoreKitConfigurationFileReference')
storekit.add_attribute('identifier', '../../Marblezzz/Resources/Marblezzz.storekit')
scheme.save_as(project.path, 'Marblezzz', true)
puts 'Generated Marblezzz.xcodeproj'
