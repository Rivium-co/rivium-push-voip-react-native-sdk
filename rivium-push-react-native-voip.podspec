require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "rivium-push-react-native-voip"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "https://github.com/Rivium-co/rivium-push-voip-react-native-sdk.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  s.dependency "React-Core"
  # RiviumPush VoIP Native SDK (CocoaPods)
  s.dependency "RiviumPushVoip", "~> 0.1"

  s.swift_version = "5.0"
  s.frameworks = "PushKit", "CallKit"
end
