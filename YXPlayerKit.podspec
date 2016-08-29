#
#  Be sure to run `pod spec lint YXPlayerKit.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "YXPlayerKit"
  s.author       = { "ding" => "dingyp@yunxi.tv" }
  s.version      = "1.0.0"
  s.license  = "MIT"
  s.summary = "iOS video player SDK, RTMP, HLS video streaming supported." 
  s.homepage = 'https://github.com/yx-engineering/YXiOSPlayer.git'
  s.source   = { :git => "https://github.com/yx-engineering/YXiOSPlayer.git", :tag => "1.0.0" } 
  s.platform     = :ios, '8.1'
  s.requires_arc = true
  s.public_header_files = "Pod/Library/YXPlayerKit/*.h"
  s.source_files = 'Pod/Library/*'
  s.dependency "PLPlayerKit", "~> 2.0" 
end
