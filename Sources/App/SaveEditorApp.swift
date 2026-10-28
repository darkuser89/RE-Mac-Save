import SwiftUI
import AppKit
final class AppDelegate:NSObject,NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification:Notification){NSApp.setActivationPolicy(.regular);NSApp.activate(ignoringOtherApps:true)}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}
@main struct SaveEditorApp:App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body:some Scene {
        WindowGroup {ContentView().frame(minWidth:940,minHeight:620)}.defaultSize(width:1120,height:740)
        .commands {CommandGroup(replacing:.newItem) {}}
    }
}
