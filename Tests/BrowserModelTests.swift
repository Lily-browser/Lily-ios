import CryptoKit
import Foundation
import Testing
import LilyKit
@testable import Lily

@MainActor
struct BrowserModelTests {
    @Test func startsWithOneEmptyTabInTheFirstSpace() {
        let model = BrowserModel()
        #expect(model.tabs.count == 1)
        #expect(model.active.url == nil && model.active.displayTitle == "New Tab")
        #expect(model.active.spaceID == model.currentSpaceID)
    }

    @Test func typedHostBecomesHTTPSAndSearchBecomesSearchURL() {
        let model = BrowserModel()
        model.go(to: "example.com")
        #expect(model.active.url?.scheme == "https")
        model.go(to: "http://example.com")
        #expect(model.active.url?.scheme == "https")
        model.go(to: "swift concurrency")
        #expect(model.active.url?.query?.contains("swift") == true)
    }

    @Test func newTabIsSelectedAndClosingFallsBack() {
        let model = BrowserModel()
        let first = model.activeID
        model.newTab()
        #expect(model.tabs.count == 2 && model.activeID != first)
        model.close(model.activeID)
        #expect(model.activeID == first)
    }

    @Test func closingTheLastTabInASpaceLeavesAFreshOne() {
        let model = BrowserModel()
        let only = model.activeID
        model.close(only)
        #expect(model.tabs.count == 1 && model.activeID != only)
    }

    @Test func spacesKeepTheirOwnTabsAndRememberTheActiveOne() {
        let model = BrowserModel()
        let personal = model.currentSpaceID
        model.newTab()
        let personalActive = model.activeID
        model.selectSpace(model.spaces[1].id)
        #expect(model.currentSpaceID != personal)
        #expect(model.regularTabs.count == 1 && model.active.spaceID == model.currentSpaceID)
        model.selectSpace(personal)
        #expect(model.activeID == personalActive)
        #expect(model.regularTabs.count == 2)
    }

    @Test func pinningMovesATabToThePinnedGrid() {
        let model = BrowserModel()
        model.togglePin(model.activeID)
        #expect(model.pinnedTabs.count == 1 && model.regularTabs.isEmpty)
        model.togglePin(model.activeID)
        #expect(model.pinnedTabs.isEmpty && model.regularTabs.count == 1)
    }

    @Test func pageChangesUpdateTheTitleAndAddressShown() {
        let model = BrowserModel()
        model.pageChanged(model.activeID, url: URL(string: "https://www.example.com/a"), title: "Example")
        #expect(model.active.displayTitle == "Example")
        #expect(model.active.shortAddress == "example.com/a")
        #expect(model.matches("exam").count == 1)
    }
}

@MainActor
struct SessionTests {
    private struct Keys: KeyStore {
        func key(named name: String) async throws -> SymmetricKey { SymmetricKey(data: Data(repeating: 3, count: 32)) }
        func deleteKey(named name: String) async throws {}
    }
    private func tempDir() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("lily-test-\(UUID().uuidString)") }

    @Test func sessionRoundTripsThroughSealedStorageAndRestores() async {
        let dir = tempDir()
        let storage = SessionStorage(directory: dir, keys: Keys())
        let model = BrowserModel()
        model.pageChanged(model.activeID, url: URL(string: "https://example.com"), title: "Example")
        await storage.save(model.snapshot)
        let fresh = BrowserModel(storage: storage)
        await fresh.restore()
        #expect(fresh.snapshot == model.snapshot)
    }

    @Test func aLateRestoreDoesNotClobberBrowsing() async {
        let dir = tempDir()
        let storage = SessionStorage(directory: dir, keys: Keys())
        let old = BrowserModel()
        old.newTab()
        await storage.save(old.snapshot)
        let fresh = BrowserModel(storage: storage)
        fresh.go(to: "https://example.org")
        await fresh.restore()
        #expect(fresh.tabs.count == 1)
    }

    @Test func plaintextSessionsFromEarlierBuildsAreSealedAndRemoved() async throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = BrowserModel()
        model.pageChanged(model.activeID, url: URL(string: "https://example.com/?t=secret"), title: "X")
        try JSONEncoder().encode(model.snapshot).write(to: dir.appendingPathComponent("session.json"))
        let storage = SessionStorage(directory: dir, keys: Keys())
        #expect(await storage.load() == model.snapshot)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("session.json").path))
        #expect(await storage.load() == model.snapshot)
    }

    @Test func aSnapshotWithAnUnknownSpaceIsInvalid() {
        var snapshot = BrowserModel().snapshot
        snapshot.tabs[0].spaceID = UUID()
        #expect(!snapshot.isValid)
    }

    @Test func renameAndRecolorKeepASpaceUsable() {
        let model = BrowserModel()
        let space = model.currentSpace
        model.rename(space, to: "  Home  ")
        model.recolor(space, to: "#FF375F")
        #expect(model.currentSpace.name == "Home" && model.currentSpace.colorHex == "#FF375F")
        model.rename(space, to: "   ")
        #expect(model.currentSpace.name == "Home")
    }

    @Test func closeOthersKeepsPinnedAndTheChosenTab() {
        let model = BrowserModel()
        let keep = model.activeID
        model.newTab(); model.newTab()
        model.togglePin(model.activeID)
        model.closeOthers(keeping: keep)
        #expect(model.regularTabs.map(\.id) == [keep] && model.pinnedTabs.count == 1)
    }
}
