// AddAlarmAddressComponents.swift

import SwiftUI

// MARK: - Address Row View for Address Selector
struct AddressSelectorRowView: View {
    let address: Address
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 25)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(address.customLabel ?? address.label.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(address.shortDisplayAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

// MARK: - Address Selector Sheet
struct AddressSelectorSheet: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Home Address
                if let homeAddress = viewModel.profileViewModel.homeAddress, homeAddress.isValid {
                    AddressSelectorRowView(
                        address: homeAddress,
                        icon: "house.fill",
                        iconColor: .customBlue
                    ) {
                        viewModel.selectSavedAddress(homeAddress, for: viewModel.selectedAddressType!)
                        dismiss()
                    }
                }
                
                // Work Address
                if let workAddress = viewModel.profileViewModel.workAddress, workAddress.isValid {
                    AddressSelectorRowView(
                        address: workAddress,
                        icon: "building.2.fill",
                        iconColor: .orange
                    ) {
                        viewModel.selectSavedAddress(workAddress, for: viewModel.selectedAddressType!)
                        dismiss()
                    }
                }
                
                // Custom Addresses
                if !viewModel.profileViewModel.customAddresses.isEmpty {
                    Section("Saved Locations") {
                        ForEach(viewModel.profileViewModel.customAddresses) { address in
                            AddressSelectorRowView(
                                address: address,
                                icon: "mappin.circle.fill",
                                iconColor: .green
                            ) {
                                viewModel.selectSavedAddress(address, for: viewModel.selectedAddressType!)
                                dismiss()
                            }
                        }
                    }
                }
                
                // Add New Address
                Section {
                    Button {
                        dismiss()
                        viewModel.showAddNewAddress = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.customBlue)
                            Text("Add New Address")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add New Address Sheet
struct AddNewAddressSheet: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var customLabel = ""
    @State private var newAddress = Address(label: .custom, street: "", city: "", zip: "", state: "Select")
    @State private var saveToProfile = true
    @State private var setAsDefault = false
    
    var canSave: Bool {
        !customLabel.isEmpty && customLabel.count <= 20 && newAddress.isValid
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Location Name (e.g., Gym, Office)", text: $customLabel)
                        .frame(minHeight: 44)
                } header: {
                    Text("Label")
                } footer: {
                    Text("Give this address a memorable name")
                }
                
                Section("Address") {
                    TextField("Street Address", text: $newAddress.street)
                        .frame(minHeight: 44)
                    TextField("City", text: $newAddress.city)
                        .frame(minHeight: 44)
                    
                    HStack {
                        TextField("ZIP Code", text: $newAddress.zip)
                            .keyboardType(.numberPad)
                            .frame(minHeight: 44)
                            .onChange(of: newAddress.zip) { _, newValue in
                                if newValue.count > 5 {
                                    newAddress.zip = String(newValue.prefix(5))
                                }
                            }
                        
                        Picker("State", selection: $newAddress.state) {
                            ForEach(viewModel.states, id: \.self) { state in
                                Text(state).tag(state)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: 44)
                    }
                }
                
                Section("Options") {
                    Toggle("Save to Profile", isOn: $saveToProfile)
                        .frame(minHeight: 44)
                    
                    if saveToProfile && (customLabel.lowercased().contains("home") || customLabel.lowercased().contains("work")) {
                        Toggle("Set as Default \(customLabel.lowercased().contains("home") ? "Home" : "Work") Address", isOn: $setAsDefault)
                            .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Add Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var addressToSave = newAddress
                        addressToSave.customLabel = customLabel
                        
                        // Use address for current alarm
                        viewModel.selectSavedAddress(addressToSave, for: viewModel.selectedAddressType!)
                        
                        // Save to profile if requested
                        if saveToProfile {
                            if setAsDefault {
                                if customLabel.lowercased().contains("home") {
                                    addressToSave.label = .home
                                } else if customLabel.lowercased().contains("work") {
                                    addressToSave.label = .work
                                }
                            }
                            viewModel.profileViewModel.addCustomLocation(addressToSave)
                        }
                        
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
