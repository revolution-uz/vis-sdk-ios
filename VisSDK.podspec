Pod::Spec.new do |s|
  s.name             = 'VisSDK'
  s.version          = '1.0.3'
  s.summary          = 'Vis identity-verification SDK for iOS.'
  s.description      = <<-DESC
    Native iOS SDK for the Vis identity-verification platform: document capture
    with quality gates and MRZ pre-check, a liveness selfie clip that follows the
    server timeline, App Attest device evidence and a pinned DPoP transport,
    returning one typed result to the host app. Localized in uz, ru and en.
  DESC
  s.homepage         = 'https://github.com/revolution-uz/vis-sdk-ios'
  s.license          = { :type => 'Proprietary', :text => 'See https://github.com/revolution-uz/vis-sdk-ios/blob/master/LICENSE' }
  s.author           = 'vis.uz'
  s.source           = {
    :http   => "https://github.com/revolution-uz/vis-sdk-ios/releases/download/#{s.version}/VisSDK.xcframework.zip",
    :sha256 => '0cf43e57262de7300a6dd4bba7ac4b1398c9374c2396e87f498dfe81d912e7b8'
  }

  s.platform         = :ios, '15.0'
  s.swift_versions   = ['5.9']
  s.vendored_frameworks = 'VisSDK.xcframework'
  s.frameworks       = 'UIKit', 'SwiftUI', 'AVFoundation', 'Vision', 'CoreMotion', 'CoreVideo', 'QuartzCore', 'CryptoKit', 'DeviceCheck', 'Security'
end
