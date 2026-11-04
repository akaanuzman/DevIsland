import XCTest
import Sparkle
@testable import DevIslandApp

@MainActor private final class UpdateStub: UpdateBackend {
    var event: ((UpdateEvent)->Void)?
    var automaticChecks=true
    var canCheck=true
    var lastCheck: Date?=Date(timeIntervalSince1970:1234)
    var checks=0,channelChanges=0
    func check() { checks+=1 }
    func channelsChanged() { channelChanges+=1 }
}
final class UpdateTests: XCTestCase {
    func testLocalAndDiagnosticBuildsCannotStartNetworkUpdater() {
        let valid:[String:Any] = ["DevIslandOfficialRelease":true,"CFBundleIdentifier":"dev.island.app","SUFeedURL":UpdateConfiguration.feed,"SUPublicEDKey":Data(repeating:1,count:32).base64EncodedString()]
        XCTAssertTrue(UpdateConfiguration.isEnabled(info:valid,arguments:[]))
        for flag in ["--demo","--render-preview","--verify-storage","--disable-updates","Tests.xctest"] { XCTAssertFalse(UpdateConfiguration.isEnabled(info:valid,arguments:[flag])) }
        for key in valid.keys { var missing=valid;missing.removeValue(forKey:key);XCTAssertFalse(UpdateConfiguration.isEnabled(info:missing,arguments:[])) }
        var wrong=valid;wrong["SUFeedURL"]="http://example.com/feed.xml";XCTAssertFalse(UpdateConfiguration.isEnabled(info:wrong,arguments:[]))
    }
    @MainActor func testUpdateSettingsPreserveAppPreferencesAndSurviveRelaunch() throws {
        let name="dev.island.updates-test."+UUID().uuidString, d=UserDefaults(suiteName:name)!
        defer { d.removePersistentDomain(forName:name) }
        let saved=Data("existing-theme-mascot-routing".utf8);d.set(saved,forKey:"preferences.v1")
        let stub=UpdateStub(),c=UpdateController(defaults:d,backend:stub)
        XCTAssertTrue(c.automaticChecks);XCTAssertFalse(c.beta)
        c.setAutomaticChecks(false);c.setBeta(true)
        XCTAssertFalse(stub.automaticChecks);XCTAssertEqual(stub.channelChanges,1)
        let restored=UpdateController(defaults:d)
        XCTAssertFalse(restored.automaticChecks);XCTAssertTrue(restored.beta)
        XCTAssertEqual(d.data(forKey:"preferences.v1"),saved)
    }
    @MainActor func testManualCheckFailureAndRetryDoNotLeaveButtonStuck() {
        let d=UserDefaults(suiteName:"dev.island.update-check."+UUID().uuidString)!,stub=UpdateStub()
        let c=UpdateController(defaults:d,backend:stub)
        c.check();c.check();XCTAssertEqual(stub.checks,1);XCTAssertTrue(c.checking)
        stub.event?(.finished(URLError(.notConnectedToInternet)))
        XCTAssertFalse(c.checking);XCTAssertNotNil(c.errorMessage);XCTAssertTrue(c.canCheck)
        c.check();stub.event?(.current);stub.event?(.finished(nil))
        XCTAssertTrue(c.isCurrent);XCTAssertNil(c.errorMessage);XCTAssertEqual(c.lastCheck,stub.lastCheck)
        stub.event?(.available("0.4.1"));XCTAssertEqual(c.availableVersion,"0.4.1")
        c.setBeta(false);XCTAssertNil(c.availableVersion)
    }
    func testSparkleUsesIncreasingNumericBuildsAcrossBetaAndStable() {
        let comparator=SUStandardVersionComparator.default
        // Display SemVer strings are release labels; CFBundleVersion orders every channel.
        XCTAssertEqual(comparator.compareVersion("11",toVersion:"12"),.orderedAscending)
        XCTAssertEqual(comparator.compareVersion("12",toVersion:"13"),.orderedAscending)
        XCTAssertEqual(comparator.compareVersion("13",toVersion:"10"),.orderedDescending)
    }
}
