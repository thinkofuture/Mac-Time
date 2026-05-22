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
            Text("Edit Session")
                .font(.headline)

            Form {
                TextField("App Name", text: $appName)
                TextField("Bundle ID", text: $bundleId)
                DatePicker("Start Time", selection: $start)
                DatePicker("End Time", selection: $end)
            }
            .padding()

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
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
