import SwiftUI

struct AddUnitFromTreatmentView: View {
    @ObservedObject var appData: AppData
    @Binding var selectedUnit: Unit?
    @State private var unitName: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            TextField("Unit", text: $unitName)
        }
        .navigationBarTitle("Add Unit", displayMode: .inline)
        .navigationBarItems(trailing: Button("Save") {
            if !unitName.isEmpty {
                let newUnit = Unit(name: unitName)
                appData.units.append(newUnit)
                selectedUnit = newUnit
                dismiss()
            }
        })
    }
}
