// Friday — local-first macOS assistant
// Copyright (c) 2026 Dhruv Chawla
// SPDX-License-Identifier: MIT

import CoreGraphics
import Foundation
import Testing

@testable import Friday

struct OrbPlacementTests {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 870)
    let size = CGSize(width: 58, height: 58)

    @Test func defaultsToTopRightWhenNothingIsBusy() {
        let point = OrbPlacement.automaticOrigin(visible: visible, size: size, busy: [])
        #expect(point == CGPoint(x: 1440 - 14 - 58, y: 870 - 14 - 58))
    }

    @Test func avoidsBrowserToolbarAcrossTheTopWithoutUsingTheBottom() {
        let browser = CGRect(x: 0, y: 0, width: 1440, height: 870)
        let busy = OrbPlacement.busyZones(windows: [browser], isDesktop: false, visible: visible)
        let point = OrbPlacement.automaticOrigin(visible: visible, size: size, busy: busy)
        #expect(point == OrbPlacement.origin(of: .rightMiddle, in: visible, size: size))
        #expect(point.y > visible.minY + OrbPlacement.margin)
    }

    @Test func topCenterIsUsedWhenBothCornersAreBusy() {
        let left = CGRect(x: 0, y: 0, width: 500, height: 870)
        let right = CGRect(x: 940, y: 0, width: 500, height: 870)
        let busy = OrbPlacement.busyZones(windows: [left, right], isDesktop: false, visible: visible)
        let point = OrbPlacement.automaticOrigin(visible: visible, size: size, busy: busy)
        #expect(point == OrbPlacement.origin(of: .topCenter, in: visible, size: size))
        #expect(point == CGPoint(x: 720 - 29, y: 870 - 14 - 58))
    }

    @Test func noFreeAnchorPicksTheLeastBusyTopAnchor() {
        func orbRect(_ anchor: OrbPlacement.Anchor) -> CGRect {
            CGRect(origin: OrbPlacement.origin(of: anchor, in: visible, size: size), size: size)
        }
        // Every anchor is fully covered except for a small sliver over top-left.
        let topLeft = orbRect(.topLeft)
        let busy =
            [OrbPlacement.Anchor.topRight, .topCenter, .rightMiddle, .leftMiddle].map {
                orbRect($0).insetBy(dx: -10, dy: -10)
            } + [CGRect(x: topLeft.minX, y: topLeft.minY, width: 5, height: 5)]
        let point = OrbPlacement.automaticOrigin(visible: visible, size: size, busy: busy)
        #expect(point == OrbPlacement.origin(of: .topLeft, in: visible, size: size))
    }

    @Test func noAnchorSitsAtTheBottom() {
        for anchor in OrbPlacement.Anchor.allCases {
            let point = OrbPlacement.origin(of: anchor, in: visible, size: size)
            #expect(point.y > visible.minY + OrbPlacement.margin)
        }
    }

    @Test func smallWindowOnTheLeftKeepsTopRightFree() {
        let window = CGRect(x: 100, y: 300, width: 600, height: 500)
        let busy = OrbPlacement.busyZones(windows: [window], isDesktop: false, visible: visible)
        let point = OrbPlacement.automaticOrigin(visible: visible, size: size, busy: busy)
        #expect(point == OrbPlacement.origin(of: .topRight, in: visible, size: size))
    }

    @Test func avoidsToolbarsOfEveryVisibleWindow() {
        // Browser on the left half, desktop icons exposed on the right.
        let browser = CGRect(x: 0, y: 0, width: 900, height: 870)
        let busy = OrbPlacement.busyZones(windows: [browser], isDesktop: true, visible: visible)
        let point = OrbPlacement.automaticOrigin(visible: visible, size: size, busy: busy)
        #expect(point == OrbPlacement.origin(of: .leftMiddle, in: visible, size: size))
    }

    @Test func desktopAvoidsIconColumnOnTheRight() {
        let busy = OrbPlacement.busyZones(windows: [], isDesktop: true, visible: visible)
        let point = OrbPlacement.automaticOrigin(visible: visible, size: size, busy: busy)
        #expect(point == OrbPlacement.origin(of: .topLeft, in: visible, size: size))
    }

    @Test func dropIsClampedOnScreenAndSnappedToEdges() {
        #expect(
            OrbPlacement.snapped(CGPoint(x: -200, y: 5000), visible: visible, size: size)
                == CGPoint(x: 14, y: 870 - 14 - 58))
        #expect(
            OrbPlacement.snapped(CGPoint(x: 1340, y: 400), visible: visible, size: size) == CGPoint(x: 1368, y: 400))
        #expect(OrbPlacement.snapped(CGPoint(x: 700, y: 400), visible: visible, size: size) == CGPoint(x: 700, y: 400))
    }

    @Test func relativePositionRoundTripsAcrossScreens() {
        let point = CGPoint(x: 700, y: 400)
        let relative = OrbPlacement.relative(point, visible: visible, size: size)
        #expect(OrbPlacement.absolute(relative, visible: visible, size: size) == point)

        let external = CGRect(x: 1440, y: -200, width: 2560, height: 1415)
        let moved = OrbPlacement.absolute(relative, visible: external, size: size)
        #expect(external.contains(CGRect(origin: moved, size: size)))
    }

    @Test func positionStoreSavesPerApp() {
        let store = OrbPositionStore(suite: "friday.tests.orb.\(UUID().uuidString)")
        store.save(CGPoint(x: 0.9, y: 0.1), for: "com.google.Chrome")
        #expect(store.position(for: "com.google.Chrome") == CGPoint(x: 0.9, y: 0.1))
        #expect(store.position(for: OrbPositionStore.desktopKey) == nil)
        store.reset("com.google.Chrome")
        #expect(store.position(for: "com.google.Chrome") == nil)
    }
}
