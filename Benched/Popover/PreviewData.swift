#if DEBUG
    import Foundation

    enum PreviewData {
        // 2026-11-03 10:00 UTC
        static let now = Date(timeIntervalSince1970: 1_793_700_000)

        static let normal = snapshot([
            meter(.session, percent: 23, resetsIn: 2 * 3600 + 14 * 60, isActive: true),
            meter(.weeklyAll, percent: 41, resetsIn: 5 * 86400 + 21 * 3600),
        ])

        static let warningAndCritical = snapshot([
            meter(.session, percent: 96, resetsIn: 40 * 60, severity: .critical, isActive: true),
            meter(.weeklyAll, percent: 83, resetsIn: 2 * 86400, severity: .warning),
        ])

        static let overLimit = snapshot([
            meter(.session, percent: 104, resetsIn: 50, severity: .critical, isActive: true),
            meter(.weeklyAll, percent: 61, resetsIn: 3 * 86400),
        ])

        static let manyRows = snapshot([
            meter(.session, percent: 12, resetsIn: 3 * 3600),
            meter(.weeklyAll, percent: 41, resetsIn: 4 * 86400, isActive: true),
            meter(MeterKind(rawValue: "monthly_all"), percent: 18, resetsIn: 20 * 86400),
            // A kind added later shows with its raw name humanised, however long it is
            meter(MeterKind(rawValue: "weekly_all_surfaces_including_a_very_long_new_name"), percent: 55, resetsIn: 4 * 86400),
        ])

        static let empty = snapshot([])

        static let rowsDropped = snapshot(
            [meter(.session, percent: 23, resetsIn: 2 * 3600, isActive: true)],
            droppedRows: 2,
        )

        static func snapshot(
            _ meters: [Meter],
            droppedRows: Int = 0,
            observedAt: Date = now.addingTimeInterval(-120),
        ) -> UsageSnapshot {
            UsageSnapshot(meters: meters, observedAt: observedAt, droppedRows: droppedRows)
        }

        static func meter(
            _ kind: MeterKind,
            percent: Double,
            resetsIn: TimeInterval,
            severity: SeverityLevel = .normal,
            isActive: Bool = false,
        ) -> Meter {
            Meter(
                kind: kind,
                percent: percent,
                resetsAt: now.addingTimeInterval(resetsIn),
                severity: severity,
                isActive: isActive,
            )
        }
    }
#endif
