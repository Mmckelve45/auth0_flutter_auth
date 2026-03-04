Pod::Spec.new do |s|
  s.name             = 'auth0_flutter_auth'
  s.version          = '0.1.0'
  s.summary          = 'Auth0 Flutter SDK — native browser and DPoP plugins.'
  s.description      = 'Minimal native bridge for ASWebAuthenticationSession and Secure Enclave DPoP.'
  s.homepage         = 'https://auth0.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Auth0' => 'support@auth0.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'AuthenticationServices', 'Security'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
