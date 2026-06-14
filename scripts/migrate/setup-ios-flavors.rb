#!/usr/bin/env ruby
# One-shot migration: split the iOS Runner project into per-flavor configurations
# and add the Firebase GoogleService-Info.plist copy build phase.
#
# Usage: GEM_HOME="$(brew --prefix cocoapods)/libexec" ruby scripts/migrate/setup-ios-flavors.rb
#
# This script is deleted after the migration lands; the resulting
# project.pbxproj diff is the durable artifact.

require 'xcodeproj'

FLAVORS = %w[dev staging production].freeze
MODES   = %w[Debug Release Profile].freeze

REPO_ROOT     = File.expand_path(File.join(__dir__, '..', '..'))
PROJECT_PATH  = File.join(REPO_ROOT, 'peppercheck_flutter', 'ios', 'Runner.xcodeproj')
FLUTTER_GROUP = 'Flutter' # PBXGroup name where per-flavor xcconfigs live (sourceTree-relative)

project = Xcodeproj::Project.open(PROJECT_PATH)

runner       = project.targets.find { |t| t.name == 'Runner'       } or abort 'Runner target not found'
runner_tests = project.targets.find { |t| t.name == 'RunnerTests'  } or abort 'RunnerTests target not found'

flutter_group = project.main_group[FLUTTER_GROUP] or abort 'Flutter group not found in main group'

# --- 1. Add PBXFileReference for each new xcconfig in the Flutter group --------
def ensure_xcconfig_ref(group, filename)
  existing = group.files.find { |f| f.path == "Flutter/#{filename}" || f.display_name == filename }
  return existing if existing
  ref = group.new_reference("Flutter/#{filename}", :group)
  ref.last_known_file_type = 'text.xcconfig'
  ref.name = filename
  ref
end

combined_refs = {}
MODES.each do |mode|
  FLAVORS.each do |flavor|
    name = "#{mode}-#{flavor}.xcconfig"
    combined_refs["#{mode}-#{flavor}"] = ensure_xcconfig_ref(flutter_group, name)
  end
end

# Remove the legacy mode-base PBXFileReferences (Debug.xcconfig / Release.xcconfig)
# from the Flutter group — they are no longer referenced by any build configuration.
%w[Debug.xcconfig Release.xcconfig].each do |legacy|
  legacy_ref = flutter_group.files.find { |f| f.display_name == legacy }
  legacy_ref&.remove_from_project
end

# Note: RunnerTests' baseConfigurationReference is intentionally left unset on the
# new configurations. CocoaPods's `pod install` (Step 6.1) will regenerate
# Pods-RunnerTests.<config>.xcconfig per the new config names and wire each
# configuration's baseConfigurationReference itself. We do not need to manage
# the Pods group's PBXFileReferences manually — pod install reconciles them.

# --- 2. Replace the three configurations on the project ----------------------
project_cfg_list = project.build_configuration_list
old_project_cfgs = project_cfg_list.build_configurations.dup

# Snapshot settings per mode (Debug / Release / Profile) before we delete anything.
project_mode_settings = MODES.to_h do |mode|
  cfg = old_project_cfgs.find { |c| c.name == mode } or abort "Project #{mode} config not found"
  [mode, cfg.build_settings.dup]
end

# Delete old configs (also detaches from list).
old_project_cfgs.each { |c| project_cfg_list.build_configurations.delete(c); c.remove_from_project }

# Add nine new configurations.
MODES.each do |mode|
  FLAVORS.each do |flavor|
    new_cfg = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    new_cfg.name = "#{mode}-#{flavor}"
    new_cfg.build_settings = project_mode_settings[mode].dup
    project_cfg_list.build_configurations << new_cfg
  end
end

# --- 3. Replace the three configurations on the Runner target ----------------
runner_cfg_list = runner.build_configuration_list
old_runner_cfgs = runner_cfg_list.build_configurations.dup

runner_mode_settings_and_baseref = MODES.to_h do |mode|
  cfg = old_runner_cfgs.find { |c| c.name == mode } or abort "Runner #{mode} config not found"
  settings = cfg.build_settings.dup
  # Strip PRODUCT_BUNDLE_IDENTIFIER — xcconfig now supplies it.
  settings.delete('PRODUCT_BUNDLE_IDENTIFIER')
  [mode, settings]
end

old_runner_cfgs.each { |c| runner_cfg_list.build_configurations.delete(c); c.remove_from_project }

MODES.each do |mode|
  FLAVORS.each do |flavor|
    new_cfg = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    new_cfg.name = "#{mode}-#{flavor}"
    new_cfg.build_settings = runner_mode_settings_and_baseref[mode].dup
    new_cfg.base_configuration_reference = combined_refs["#{mode}-#{flavor}"]
    runner_cfg_list.build_configurations << new_cfg
  end
end

# --- 4. Replace the three configurations on the RunnerTests target -----------
tests_cfg_list = runner_tests.build_configuration_list
old_tests_cfgs = tests_cfg_list.build_configurations.dup

tests_mode_settings = MODES.to_h do |mode|
  cfg = old_tests_cfgs.find { |c| c.name == mode } or abort "RunnerTests #{mode} config not found"
  [mode, cfg.build_settings.dup]
end

old_tests_cfgs.each { |c| tests_cfg_list.build_configurations.delete(c); c.remove_from_project }

MODES.each do |mode|
  FLAVORS.each do |flavor|
    new_cfg = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    new_cfg.name = "#{mode}-#{flavor}"
    new_cfg.build_settings = tests_mode_settings[mode].dup
    # baseConfigurationReference left unset; pod install wires it in Step 6.1.
    tests_cfg_list.build_configurations << new_cfg
  end
end

# Update defaultConfigurationName on every configuration list (was 'Release').
[project_cfg_list, runner_cfg_list, tests_cfg_list].each do |list|
  list.default_configuration_name = 'Release-production'
end

# --- 5. Add the "Inject Firebase GoogleService-Info.plist" Run Script Phase --
existing_phase = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Inject Firebase GoogleService-Info.plist' }
unless existing_phase
  phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
  phase.name = 'Inject Firebase GoogleService-Info.plist'
  phase.shell_path = '/bin/sh'
  phase.shell_script = <<~SCRIPT
    set -e
    SRC="${SRCROOT}/Runner/Firebase/GoogleService-Info-${FIREBASE_PLIST_FLAVOR}.plist"
    DST="${SRCROOT}/Runner/GoogleService-Info.plist"
    if [ ! -f "$SRC" ]; then
      echo "error: $SRC not found — run scripts/setup/register-firebase-apps.sh first" >&2
      exit 1
    fi
    cp "$SRC" "$DST"
  SCRIPT
  phase.input_paths  = ['$(SRCROOT)/Runner/Firebase/GoogleService-Info-$(FIREBASE_PLIST_FLAVOR).plist']
  phase.output_paths = ['$(SRCROOT)/Runner/GoogleService-Info.plist']
  phase.show_env_vars_in_log = '0'

  # Position: immediately after [CP] Check Pods Manifest.lock (which is index 0).
  manifest_check = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == '[CP] Check Pods Manifest.lock' }
  insert_at = manifest_check ? runner.build_phases.index(manifest_check) + 1 : 0

  runner.build_phases.insert(insert_at, phase)
end

project.save
puts 'OK: project.pbxproj migrated.'
