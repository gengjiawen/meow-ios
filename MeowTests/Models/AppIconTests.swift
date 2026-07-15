import Foundation
@testable import meow_ios
import Testing

@Suite("AppIcon model")
struct AppIconTests {
    @Test
    func `primary maps to a nil alternate icon name`() {
        #expect(AppIcon.primary.alternateIconName == nil)
    }

    @Test
    func `alternate icons pass their asset name to UIKit`() {
        #expect(AppIcon.leap.alternateIconName == "AppIconLeap")
    }

    @Test
    func `every case round-trips through alternateIconName`() {
        // `UIApplication.alternateIconName` is the only persistence for the
        // icon choice — the Settings picker restores its selection through
        // this init, so the mapping must be lossless for every case.
        for icon in AppIcon.allCases {
            #expect(AppIcon(alternateIconName: icon.alternateIconName) == icon)
        }
    }

    @Test
    func `unknown or stale icon names fall back to primary`() {
        #expect(AppIcon(alternateIconName: "RemovedInSomeUpdate") == .primary)
    }

    @Test
    func `asset names and title keys are unique across cases`() {
        #expect(Set(AppIcon.allCases.map(\.rawValue)).count == AppIcon.allCases.count)
        #expect(Set(AppIcon.allCases.map(\.titleKey)).count == AppIcon.allCases.count)
    }

    @Test
    func `every title key resolves in the en strings catalogue`() throws {
        // `Bundle.main` is the host app bundle (see LocalizableParityTests);
        // zh-Hans coverage follows from the en ⇄ zh-Hans parity suite.
        let path = try #require(Bundle.main.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: "en",
        ))
        let table = NSDictionary(contentsOfFile: path) as? [String: String] ?? [:]
        for icon in AppIcon.allCases {
            #expect(table[icon.titleKey] != nil, "missing en string for \(icon.titleKey)")
        }
    }
}
