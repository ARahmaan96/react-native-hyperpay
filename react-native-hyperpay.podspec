require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-hyperpay"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]
  s.platforms    = { :ios => "12.0" }
  s.source       = { :git => "git@github.com:ARahmaan96/react-native-hyperpay.git", :tag => "#{s.version}" }
  s.source_files = "ios/**/*.{h,m,mm}"
  s.dependency "React-Core"
  s.requires_arc = true
  s.vendored_frameworks = "OPPWAMobile.xcframework"
end
