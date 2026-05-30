import SwiftUI

struct SessionEditView: View {
    let session: Session
    var onSave: (String, String, Date, Date) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var appName: String
    @State private var bundleId: String
    @State private var start: Date
    @State private var end: Date

    init(session: Session, onSave: @escaping (String, String, Date, Date) -> Void) {
        self.session = session
        self.onSave = onSave
        _appName = State(initialValue: session.appName)
        _bundleId = State(initialValue: session.bundleId)
        _start = State(initialValue: session.startAt)
        _end = State(initialValue: session.endAt)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.Sessions.editTitle)
                .font(.headline)

            Form {
                TextField(L10n.Sessions.appName, text: $appName)
                TextField(L10n.Sessions.bundleID, text: $bundleId)
                DatePicker(L10n.Sessions.startTime, selection: $start)
                DatePicker(L10n.Sessions.endTime, selection: $end)
            }
            .padding()

            HStack {
                Button(L10n.Sessions.cancel) {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.Sessions.save) {
                    onSave(appName, bundleId, start, end)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
}
