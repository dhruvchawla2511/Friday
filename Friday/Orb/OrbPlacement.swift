// Friday — local-first macOS assistant
// Copyright (c) 2026 Dhruv Chawla
// SPDX-License-Identifier: MIT

import CoreGraphics

/// Decides where the orb sits. Pure geometry in AppKit screen coordinates
/// (origin bottom-left), so it is fully unit-testable.
enum OrbPlacement {
    static let margin: CGFloat = 14
    static let snapDistance: CGFloat = 56
    /// Height of the area at the top of a window treated as busy
    /// (title bar, tabs, toolbar, traffic-light buttons).
    static let toolbarHeight: CGFloat = 96
    /// Width of the column on the right of the desktop where macOS places icons.
    static let desktopIconColumn: CGFloat = 170

    /// Automatic search order. There are no bottom anchors: the bottom edge
    /// belongs to the Dock and its menus.
    enum Anchor: CaseIterable {
        case topRight, topLeft, topCenter, rightMiddle, leftMiddle

        static let top: [Anchor] = [.topRight, .topLeft, .topCenter]
    }

    static func origin(of anchor: Anchor, in visible: CGRect, size: CGSize) -> CGPoint {
        let left = visible.minX + margin
        let right = visible.maxX - margin - size.width
        let top = visible.maxY - margin - size.height
        let center = visible.midX - size.width / 2
        let middle = visible.midY - size.height / 2
        switch anchor {
        case .topRight: return CGPoint(x: right, y: top)
        case .topLeft: return CGPoint(x: left, y: top)
        case .topCenter: return CGPoint(x: center, y: top)
        case .rightMiddle: return CGPoint(x: right, y: middle)
        case .leftMiddle: return CGPoint(x: left, y: middle)
        }
    }

    /// Areas the orb should not cover. `windows` are the frames of visible app
    /// windows; each one's top strip (title bar, tabs, toolbar) is busy.
    static func busyZones(windows: [CGRect], isDesktop: Bool, visible: CGRect) -> [CGRect] {
        var zones: [CGRect] = []
        for frame in windows {
            let window = frame.intersection(visible)
            guard !window.isNull, window.width > 0 else { continue }
            zones.append(
                CGRect(x: window.minX, y: window.maxY - toolbarHeight, width: window.width, height: toolbarHeight))
        }
        if isDesktop {
            zones.append(
                CGRect(
                    x: visible.maxX - desktopIconColumn, y: visible.minY, width: desktopIconColumn,
                    height: visible.height))
        }
        return zones
    }

    /// The first anchor whose rectangle avoids every busy zone. If none is free,
    /// the top anchor that overlaps busy zones the least (ties go to search order).
    static func automaticOrigin(visible: CGRect, size: CGSize, busy: [CGRect]) -> CGPoint {
        func padded(_ anchor: Anchor) -> CGRect {
            CGRect(origin: origin(of: anchor, in: visible, size: size), size: size).insetBy(dx: -4, dy: -4)
        }
        for anchor in Anchor.allCases where !busy.contains(where: { $0.intersects(padded(anchor)) }) {
            return origin(of: anchor, in: visible, size: size)
        }
        func overlap(_ anchor: Anchor) -> CGFloat {
            let rect = padded(anchor)
            return busy.reduce(0) { total, zone in
                let shared = zone.intersection(rect)
                return shared.isNull ? total : total + shared.width * shared.height
            }
        }
        var best = Anchor.topRight
        for anchor in Anchor.top where overlap(anchor) < overlap(best) { best = anchor }
        return origin(of: best, in: visible, size: size)
    }

    /// Keeps a dropped orb on screen and snaps it to nearby edges.
    static func snapped(_ point: CGPoint, visible: CGRect, size: CGSize) -> CGPoint {
        let minX = visible.minX + margin, maxX = visible.maxX - margin - size.width
        let minY = visible.minY + margin, maxY = visible.maxY - margin - size.height
        var x = min(max(point.x, minX), maxX)
        var y = min(max(point.y, minY), maxY)
        if x - minX < snapDistance { x = minX } else if maxX - x < snapDistance { x = maxX }
        if y - minY < snapDistance { y = minY } else if maxY - y < snapDistance { y = maxY }
        return CGPoint(x: x, y: y)
    }

    /// Stores a position relative to the visible frame (0…1) so it works on any screen.
    static func relative(_ point: CGPoint, visible: CGRect, size: CGSize) -> CGPoint {
        let width = max(1, visible.width - size.width), height = max(1, visible.height - size.height)
        return CGPoint(x: (point.x - visible.minX) / width, y: (point.y - visible.minY) / height)
    }

    static func absolute(_ relative: CGPoint, visible: CGRect, size: CGSize) -> CGPoint {
        let point = CGPoint(
            x: visible.minX + relative.x * (visible.width - size.width),
            y: visible.minY + relative.y * (visible.height - size.height)
        )
        return snapped(point, visible: visible, size: size)
    }
}
