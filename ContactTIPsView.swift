//
//  ContactTIPsView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/8/25.
//

import SwiftUI

struct ClinicLocation: Identifiable {
    let id = UUID()
    let name: String
    let address: String
}

struct ContactTIPsView: View {
    let locations = [
        ClinicLocation(
            name: "Long Beach Clinic",
            address: "2704 E Willow Street, Signal Hill, CA, 90755"
        ),
        ClinicLocation(
            name: "Vista Clinic",
            address: "2067 W Vista Way, Vista, CA, 92083"
        )
    ]
    
    var body: some View {
        List {
            Section(header: Text("CLINIC LOCATIONS")) {
                ForEach(locations) { location in
                    Button(action: {
                        openMapsApp(for: location)
                    }) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(location.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .foregroundColor(.blue)
                                .font(.footnote)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            
            Section(header: Text("CONTACT INFORMATION")) {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Phone:")
                    Spacer()
                    Link("(562) 490-9900", destination: URL(string: "tel:5624909900")!)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
                
                HStack {
                    Image(systemName: "printer.fill")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    Text("Fax:")
                    Spacer()
                    Link("(562) 270-1763", destination: URL(string: "tel:5622701763")!)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("EMAIL")) {
                EmailRow(icon: "envelope.fill", email: "enrollment@foodallergyinstitute.com", color: .orange)
                EmailRow(icon: "envelope.fill", email: "info@foodallergyinstitute.com", color: .green)
                EmailRow(icon: "envelope.fill", email: "scheduling@foodallergyinstitute.com", color: .purple)
                EmailRow(icon: "envelope.fill", email: "patientbilling@foodallergyinstitute.com", color: .red)
            }
            
            Section(header: Text("ONLINE SERVICES")) {
                LinkRow(
                    title: "TIPs Connect",
                    subtitle: "Report reactions, access resources, message on-call team",
                    icon: "link.circle.fill",
                    color: .blue,
                    url: "https://tipconnect.socalfoodallergy.org/"
                )
                
                LinkRow(
                    title: "QURE4U My Care Plan",
                    subtitle: "View appointments, get reminders, sign documents",
                    icon: "calendar.circle.fill",
                    color: .green,
                    url: "https://www.web.my-care-plan.com/login"
                )
                
                LinkRow(
                    title: "Athena Portal",
                    subtitle: "View appointments, discharge instructions, receipts",
                    icon: "doc.circle.fill",
                    color: .purple,
                    url: "https://11920.portal.athenahealth.com/"
                )
                
                LinkRow(
                    title: "Netsuite",
                    subtitle: "TIP fee payments, schedule payments, autopay",
                    icon: "dollarsign.circle.fill",
                    color: .orange,
                    url: "https://6340501.app.netsuite.com/app/login/secure/privatelogin.nl?c=6340501"
                )
            }
        }
        .navigationTitle("Contact TIPs")
    }
    
    func openMapsApp(for location: ClinicLocation) {
        // Format the address for URL
        let addressForURL = location.address.replacingOccurrences(of: " ", with: "+")
        
        // Try to open Apple Maps with address search
        if let url = URL(string: "maps://?address=\(addressForURL)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        
        // Fallback to Google Maps in browser if Apple Maps fails
        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(addressForURL)") {
            UIApplication.shared.open(url)
        }
    }
}

struct EmailRow: View {
    let icon: String
    let email: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Link(email, destination: URL(string: "mailto:\(email)")!)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

struct LinkRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ContactTIPsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContactTIPsView()
        }
    }
}
