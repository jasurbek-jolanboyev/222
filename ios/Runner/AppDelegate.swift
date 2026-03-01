import UIKit
import Flutter
import Firebase // Firebase-ni import qilamiz

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    FirebaseApp.configure() // Firebase-ni iOS-da ishga tushirish (GeneratedPluginRegistrant'dan oldin bo'lishi shart)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}