import WidgetKit
import SwiftUI

/// MySOS home-screen widget: a single big SOS button.
///
/// iOS widgets cannot perform network requests on tap, so tapping opens the
/// app straight into the auto-countdown SOS flow via the `mysos://fire`
/// deep link (the alert fires in ~3 seconds with a cancel window).
@main
struct SosWidgetBundle: WidgetBundle {
    var body: some Widget {
        SosWidget()
    }
}

struct SosEntry: TimelineEntry {
    let date: Date
}

struct SosProvider: TimelineProvider {
    func placeholder(in context: Context) -> SosEntry {
        SosEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (SosEntry) -> Void) {
        completion(SosEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SosEntry>) -> Void) {
        completion(Timeline(entries: [SosEntry(date: .now)], policy: .never))
    }
}

struct SosWidgetEntryView: View {
    var entry: SosEntry

    var body: some View {
        ZStack {
            Color(red: 0.827, green: 0.184, blue: 0.184)
            VStack(spacing: 2) {
                Text("SOS")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                Text("กดขอความช่วยเหลือ")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .widgetURL(URL(string: "mysos://fire"))
    }
}

struct SosWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SosWidget", provider: SosProvider()) { entry in
            SosWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SOS")
        .description("ปุ่มลัดขอความช่วยเหลือฉุกเฉิน — กดแล้วส่งแจ้งเตือนถึงผู้ดูแลทันที")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
