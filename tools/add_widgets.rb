# iOS 홈 화면 위젯(WidgetKit)을 Runner 프로젝트에 붙여요.
# 여러 번 실행해도 안전해요 (이미 붙어 있으면 파일만 다시 복사해요).
require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
IOS = File.join(ROOT, 'ios')
SRC = File.join(ROOT, 'ios_widget')
GROUP_ID = 'group.com.isla0x.yeobaek'
EXT_NAME = 'YeobaekWidgets'
URL_SCHEME = 'yeobaek'

abort 'ios 폴더가 없어요. 먼저 tools/bootstrap.sh 를 실행해요.' unless File.directory?(IOS)

# ---- 1) 파일 복사
ext_dir = File.join(IOS, EXT_NAME)
FileUtils.mkdir_p(ext_dir)
%w[Snapshot.swift Widgets.swift Info.plist YeobaekWidgets.entitlements].each do |f|
  FileUtils.cp(File.join(SRC, f), File.join(ext_dir, f))
end
File.write(File.join(IOS, 'Flutter', 'Widget.xcconfig'), "#include \"Generated.xcconfig\"\n")

project_path = File.join(IOS, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner 를 못 찾았어요.'

def setting(target, key)
  %w[Release Debug Profile].each do |cfg|
    c = target.build_configurations.find { |b| b.name == cfg }
    v = c && c.build_settings[key]
    return v if v && !v.to_s.empty?
  end
  nil
end

bundle_id = setting(runner, 'PRODUCT_BUNDLE_IDENTIFIER') || 'com.isla0x.yeobaek'
team = setting(runner, 'DEVELOPMENT_TEAM')

# ---- 2) 앱(Runner): 앱 그룹 권한 + 주소 규칙
ent_rel = setting(runner, 'CODE_SIGN_ENTITLEMENTS')
if ent_rel.nil?
  ent_rel = 'Runner/Runner.entitlements'
  FileUtils.cp(File.join(SRC, 'Runner.entitlements'), File.join(IOS, ent_rel))
  runner_group = project.main_group['Runner']
  runner_group.new_file('Runner.entitlements') if runner_group && runner_group.files.none? { |f| f.path == 'Runner.entitlements' }
  runner.build_configurations.each { |c| c.build_settings['CODE_SIGN_ENTITLEMENTS'] = ent_rel }
else
  # 이미 권한 파일이 있으면 앱 그룹만 보태요.
  path = File.join(IOS, ent_rel)
  data = File.exist?(path) ? Xcodeproj::Plist.read_from_path(path) : {}
  groups = data['com.apple.security.application-groups'] || []
  unless groups.include?(GROUP_ID)
    data['com.apple.security.application-groups'] = groups + [GROUP_ID]
    Xcodeproj::Plist.write_to_path(data, path)
  end
end

plist_path = File.join(IOS, 'Runner', 'Info.plist')
if File.exist?(plist_path)
  info = Xcodeproj::Plist.read_from_path(plist_path)
  types = info['CFBundleURLTypes'] || []
  has = types.any? { |t| (t['CFBundleURLSchemes'] || []).include?(URL_SCHEME) }
  unless has
    types << { 'CFBundleURLName' => bundle_id, 'CFBundleURLSchemes' => [URL_SCHEME] }
    info['CFBundleURLTypes'] = types
    Xcodeproj::Plist.write_to_path(info, plist_path)
  end
end

# ---- 3) 위젯 확장(target)
ext = project.targets.find { |t| t.name == EXT_NAME }
if ext.nil?
  ext = project.new_target(:app_extension, EXT_NAME, :ios, '17.0')

  group = project.main_group.new_group(EXT_NAME, EXT_NAME)
  swift_refs = %w[Snapshot.swift Widgets.swift].map { |f| group.new_file(f) }
  ext.add_file_references(swift_refs)
  group.new_file('Info.plist')
  group.new_file('YeobaekWidgets.entitlements')

  # 프로젝트 폴더(ios/) 기준 경로로 직접 가리켜요.
  xc = project.main_group.new_reference('Flutter/Widget.xcconfig')

  ext.build_configurations.each do |c|
    s = c.build_settings
    c.base_configuration_reference = xc
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.widget"
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['INFOPLIST_FILE'] = "#{EXT_NAME}/Info.plist"
    s['CODE_SIGN_ENTITLEMENTS'] = "#{EXT_NAME}/#{EXT_NAME}.entitlements"
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['DEVELOPMENT_TEAM'] = team if team
    s['SWIFT_VERSION'] = '5.0'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['SKIP_INSTALL'] = 'YES'
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
    s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  end

  # Runner 가 위젯을 먼저 만들고 앱 안에 넣도록 이어요.
  runner.add_dependency(ext)
  embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  bf = embed.add_file_reference(ext.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

  # "Thin Binary" 보다 앞에 두지 않으면 빌드가 서로 물려서 멈춰요 (Cycle 오류).
  idx = runner.build_phases.index { |p| p.respond_to?(:name) && p.name.to_s == 'Thin Binary' }
  if idx
    runner.build_phases.delete(embed)
    runner.build_phases.insert(idx, embed)
  end
  puts '위젯 확장을 붙였어요.'
else
  puts '위젯 확장이 이미 있어요. 파일만 새로 복사했어요.'
end

project.save
puts "끝! (번들 ID: #{bundle_id}.widget, 앱 그룹: #{GROUP_ID})"
