//
//  Version.swift
//  Understudy
//
//  Per project rule: the version string displayed in the UI must match
//  the Info.plist values (CFBundleShortVersionString / CFBundleVersion).
//  Both are updated by the build script; this reads them at runtime.
//

import Foundation

public enum AppVersion {
    public static var short: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }
    public static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    public static var formatted: String { "v\(short) (\(build))" }
}
