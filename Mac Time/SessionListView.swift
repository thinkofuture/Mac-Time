import SwiftUI
import Foundation

struct SessionListView: View {
    let sessions: [Session]
    var onDelete: (Session) -> Void
    var onEdit: (Session, String, String, Date, Date) -> Void

    @State private var editingSession: Session?

    var body: some View {
        Table(sessions) {
            TableColumn("App", value: \.appName)
            TableColumn("Bundle ID", value: \.bundleId)
            TableColumn("Start") { session in
                Text(session.startAt, formatter: timeFormatter)
            }
            TableColumn("End") { session in
                Text(session.endAt, formatter: timeFormatter)
            }
            TableColumn("Duration") { session in
                Text(formattedDuration(session.duration))
            }
        }
        .contextMenu(forSelectionType: Session.ID.self) { selectedIds in
            // Handle multiple selection if needed, but for now simple
            if let id = selectedIds.first, let session = sessions.first(where: { $0.id == id }) {
                Button("Edit") {
                    editingSession = session
                }
                Button("Delete") {
                    onDelete(session)
                }
            }
        }
        .sheet(item: $editingSession) { session in
            SessionEditView(session: session) { name, bundle, start, end in
                onEdit(session, name, bundle, start, end)
            }
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

