import Foundation
import Testing
@testable import Lily

/// The iPad features that mirror the Mac: split view, reopen, move, reorder, tab navigation, zoom.
@MainActor
struct MacFeatureTests {
    private func model(tabs count: Int) -> BrowserModel {
        let model = BrowserModel()
        for index in 1..<count { model.open(URL(string: "https://example.com/\(index)")!) }
        return model
    }

    @Test func splitShowsTwoPanesAndChoosingTheOtherJustMovesFocus() {
        let model = model(tabs: 3)
        let first = model.tabs[0].id, second = model.tabs[1].id
        model.select(first); model.split(with: second)
        #expect(model.splitPanes.map(\.id) == [first, second])
        model.select(second)
        #expect(model.activeID == second && model.splitID == first)
        #expect(model.splitPanes.map(\.id) == [first, second]) // sides don't swap
    }

    @Test func splittingWithTheActiveTabOrAnUnknownOneDoesNothing() {
        let model = model(tabs: 2)
        model.split(with: model.activeID); model.split(with: UUID())
        #expect(model.splitID == nil)
    }

    @Test func closingEitherPaneLeavesTheOtherAsTheOnlyPage() {
        let model = model(tabs: 3)
        let first = model.tabs[0].id, second = model.tabs[1].id
        model.select(first); model.split(with: second)
        model.close(first)
        #expect(model.splitID == nil && model.activeID == second)
        model.select(second); model.split(with: model.tabs[1].id)
        model.close(model.tabs[1].id)
        #expect(model.splitID == nil)
    }

    @Test func switchingSpaceLeavesSplitView() {
        let model = model(tabs: 2)
        model.split(with: model.tabs[0].id)
        model.selectSpace(model.spaces[1].id)
        #expect(model.splitID == nil)
    }

    @Test func reopenClosedTabBringsBackTheLastOneWithItsAddress() {
        let model = model(tabs: 3)
        let url = model.tabs[2].url
        model.close(model.tabs[2].id)
        #expect(model.canReopen)
        model.reopenClosedTab()
        #expect(model.active.url == url && !model.canReopen)
    }

    @Test func emptyTabsAreNotRemembered() {
        let model = BrowserModel()
        model.newTab(); model.close(model.activeID)
        #expect(!model.canReopen)
    }

    @Test func moveToSpaceUnpinsAndKeepsTheCurrentSpaceUsable() {
        let model = BrowserModel()
        let target = model.spaces[1]
        let id = model.activeID
        model.togglePin(id)
        model.move(id, to: target)
        #expect(model.tabs.first { $0.id == id }?.spaceID == target.id)
        #expect(model.tabs.first { $0.id == id }?.isPinned == false)
        #expect(model.tabs.contains { $0.spaceID == model.currentSpaceID } && model.active.spaceID == model.currentSpaceID)
    }

    @Test func dragReorderChangesOnlyTheUnpinnedOrder() {
        let model = model(tabs: 4)
        let ids = model.regularTabs.map(\.id)
        model.moveRegularTabs(from: IndexSet(integer: 0), to: 3)
        #expect(model.regularTabs.map(\.id) == [ids[1], ids[2], ids[0], ids[3]])
    }

    @Test func numberedShortcutsAndCyclingWrapAround() {
        let model = model(tabs: 3)
        let ids = model.currentSpaceTabs.map(\.id)
        model.selectTab(number: 1); #expect(model.activeID == ids[0])
        model.selectTab(number: 9); #expect(model.activeID == ids[2])
        model.selectTab(number: 8); #expect(model.activeID == ids[2]) // past the end: the last tab
        model.selectNextTab(1); #expect(model.activeID == ids[0])
        model.selectNextTab(-1); #expect(model.activeID == ids[2])
    }

    @Test func closeBelowKeepsTheChosenTabAndEarlierOnes() {
        let model = model(tabs: 4)
        let ids = model.regularTabs.map(\.id)
        model.closeBelow(ids[1])
        #expect(model.regularTabs.map(\.id) == [ids[0], ids[1]])
        #expect(model.activeID == ids[1])
    }

    @Test func zoomStepsPerSiteAndResets() {
        let model = BrowserModel()
        let a = URL(string: "https://www.example.com/x")!, b = URL(string: "https://other.org")!
        model.zoomStep(for: a, in: true)
        #expect(model.zoom(for: a) > 1 && model.zoom(for: b) == 1)
        #expect(model.zoom(for: URL(string: "https://example.com/y")) == model.zoom(for: a)) // www merges
        model.resetZoom(for: a)
        #expect(model.zoom(for: a) == 1)
    }
}
