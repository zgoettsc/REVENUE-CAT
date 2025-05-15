import SwiftUI

struct AddUnitView: View {
    @ObservedObject var appData: AppData
    @State private var unitName: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Unit", text: $unitName)
            }
            .navigationBarTitle("Add Unit", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !unitName.isEmpty {
                            appData.units.append(Unit(name: unitName))
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
