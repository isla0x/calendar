# iOS 앱에 언어별 안내 문구(InfoPlist.strings)를 붙여요. 여러 번 실행해도 안전해요.
# 홈 화면 이름과 캘린더 권한 안내가 폰 언어(한국어·영어·프랑스어·중국어·일본어)에 맞춰 보여요.
require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
IOS = File.join(ROOT, 'ios')
abort 'ios 폴더가 없어요. 먼저 tools/bootstrap.sh 를 실행해요.' unless File.directory?(IOS)

TEXT = {
  'ko' => {
    'CFBundleDisplayName' => '여백',
    'NSCalendarsUsageDescription' => '내 캘린더의 일정을 보여주고, 비는 시간을 찾아드리기 위해 접근해요.',
    'NSCalendarsFullAccessUsageDescription' => '내 캘린더의 일정을 보여주고, 새 일정을 추가·수정하기 위해 접근해요.',
    'NSCalendarsWriteOnlyAccessUsageDescription' => '새 일정을 내 캘린더에 추가하기 위해 접근해요.',
    'NSPhotoLibraryUsageDescription' => '백업 파일을 불러올 때 사진 보관함에서 파일을 고를 수 있도록 접근해요.',
    'NSCameraUsageDescription' => '백업 파일을 불러올 때 카메라를 쓰는 기능이 포함돼 있어요. 여백은 카메라를 따로 쓰지 않아요.',
    'NSLocationWhenInUseUsageDescription' => '여백은 위치를 사용하지 않아요. 연결된 구성 요소가 요구하는 안내 문구예요.'
  },
  'en' => {
    'CFBundleDisplayName' => 'Yeobaek',
    'NSCalendarsUsageDescription' => 'Yeobaek accesses your calendar to show your events and find your free time.',
    'NSCalendarsFullAccessUsageDescription' => 'Yeobaek accesses your calendar to show your events and to add or edit events for you.',
    'NSCalendarsWriteOnlyAccessUsageDescription' => 'Yeobaek accesses your calendar to add new events.',
    'NSPhotoLibraryUsageDescription' => 'Yeobaek lets you pick a backup file when restoring. Your photos are not read.',
    'NSCameraUsageDescription' => 'A component used for picking backup files includes camera support. Yeobaek does not use the camera.',
    'NSLocationWhenInUseUsageDescription' => 'Yeobaek does not use your location. This text is required by a bundled component.'
  },
  'fr' => {
    'CFBundleDisplayName' => 'Yeobaek',
    'NSCalendarsUsageDescription' => "Yeobaek accède à votre calendrier pour afficher vos événements et trouver votre temps libre.",
    'NSCalendarsFullAccessUsageDescription' => "Yeobaek accède à votre calendrier pour afficher vos événements et pour en ajouter ou en modifier à votre demande.",
    'NSCalendarsWriteOnlyAccessUsageDescription' => "Yeobaek accède à votre calendrier pour y ajouter de nouveaux événements.",
    'NSPhotoLibraryUsageDescription' => "Yeobaek vous permet de choisir un fichier de sauvegarde lors de la restauration. Vos photos ne sont pas lues.",
    'NSCameraUsageDescription' => "Un composant servant à choisir un fichier de sauvegarde inclut la prise en charge de l'appareil photo. Yeobaek n'utilise pas l'appareil photo.",
    'NSLocationWhenInUseUsageDescription' => "Yeobaek n'utilise pas votre position. Ce texte est exigé par un composant intégré."
  },
  'zh-Hans' => {
    'CFBundleDisplayName' => 'Yeobaek',
    'NSCalendarsUsageDescription' => 'Yeobaek 需要访问您的日历，以显示日程并找出您的空闲时间。',
    'NSCalendarsFullAccessUsageDescription' => 'Yeobaek 需要访问您的日历，以显示日程，并按您的要求添加或修改日程。',
    'NSCalendarsWriteOnlyAccessUsageDescription' => 'Yeobaek 需要访问您的日历，以添加新日程。',
    'NSPhotoLibraryUsageDescription' => '恢复备份时，Yeobaek 让您选择备份文件，不会读取您的照片。',
    'NSCameraUsageDescription' => '用于选择备份文件的组件包含相机功能，Yeobaek 本身不使用相机。',
    'NSLocationWhenInUseUsageDescription' => 'Yeobaek 不使用您的位置信息。此说明由内置组件要求提供。'
  },
  'ja' => {
    'CFBundleDisplayName' => 'Yeobaek',
    'NSCalendarsUsageDescription' => 'Yeobaek は、予定を表示し空き時間を見つけるためにカレンダーへアクセスします。',
    'NSCalendarsFullAccessUsageDescription' => 'Yeobaek は、予定を表示し、ご希望に応じて予定を追加・変更するためにカレンダーへアクセスします。',
    'NSCalendarsWriteOnlyAccessUsageDescription' => 'Yeobaek は、新しい予定を追加するためにカレンダーへアクセスします。',
    'NSPhotoLibraryUsageDescription' => '復元の際にバックアップファイルを選べるようにするためのものです。写真は読み取りません。',
    'NSCameraUsageDescription' => 'バックアップファイルを選ぶ部品にカメラ機能が含まれています。Yeobaek 自体はカメラを使いません。',
    'NSLocationWhenInUseUsageDescription' => 'Yeobaek は位置情報を使いません。この文言は組み込み部品が要求するものです。'
  }
}.freeze

def esc(s)
  s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
end

# ---- 1) 파일 쓰기
TEXT.each do |lang, kv|
  dir = File.join(IOS, 'Runner', "#{lang}.lproj")
  FileUtils.mkdir_p(dir)
  body = kv.map { |k, v| "\"#{k}\" = \"#{esc(v)}\";" }.join("\n") + "\n"
  File.write(File.join(dir, 'InfoPlist.strings'), body)
end

# ---- 2) Xcode 프로젝트에 붙이기
project = Xcodeproj::Project.open(File.join(IOS, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner 를 못 찾았어요.'
group = project.main_group['Runner'] or abort 'Runner 그룹을 못 찾았어요.'

vg = group.children.find { |c| c.isa == 'PBXVariantGroup' && c.name == 'InfoPlist.strings' }
vg ||= group.new_variant_group('InfoPlist.strings')
TEXT.each_key do |lang|
  rel = "#{lang}.lproj/InfoPlist.strings"
  next if vg.children.any? { |c| c.path == rel }
  ref = vg.new_reference(rel)
  ref.name = lang
  ref.last_known_file_type = 'text.plist.strings'
end
unless runner.resources_build_phase.files_references.include?(vg)
  runner.resources_build_phase.add_file_reference(vg)
end

regions = (project.root_object.known_regions || []) | (TEXT.keys + ['Base'])
project.root_object.known_regions = regions
project.save
puts "언어별 안내 문구 붙이기 끝: #{TEXT.keys.join(', ')}"
