import SwiftUI
import AVKit

struct OnboardingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isShowingOnboarding: Bool
    @State private var currentPage = 0
    @State private var players: [Int: AVPlayer] = [:] // Store players for each page
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Understanding Cycles",
            content: "",
            imageName: "cycle-graphic"
        ),
        OnboardingPage(
            title: "Rooms & Subscriptions",
            content: "Manage multiple participant treatment plans through Rooms. Each subscription tier allows a specific number of rooms. Switch between rooms in Settings > Rooms and Subscriptions. Each room maintains separate cycles, items, and logging history. Joining rooms is always free!",
            imageName: "rooms-video"
        ),
        OnboardingPage(
            title: "Sharing & Invitations",
            content: "Invite others to your room in Settings > Invite & Manage Users. Share the generated code with caregivers, family members, or clinicians. Admins can invite memebers to the room or remove members from the room.",
            imageName: "invitations-video"
        ),
        OnboardingPage(
            title: "Home Tab",
            content: "The Home tab is where items are logged and treatment active treatment timers are displayed. Treatment timers appear after logging treatment items. Recommended foods show progress indicators to with a goal of 3-5x per week.",
            imageName: "home-video"
        ),
        OnboardingPage(
            title: "Week View",
            content: "The Week View shows your logging history in a calendar format. Green checkmarks indicate logged items, red triangles show reactions. For recommended foods, item titles turn green after 3 weekly doses are logged. A legend is present at the bottom of the page. Swipe left/right to navigate between weeks and cycles.",
            imageName: "week-view-video"
        ),
        OnboardingPage(
            title: "Logging Reactions",
            content: "If a reaction occurs, tap the Reactions tab and use the + button to log details. You can record the specific item that caused the reaction (or select 'Unknown'), symptoms experienced, and add notes about the reaction's severity, duration, and treatment rendered.",
            imageName: "reactions-video"
        ),
        OnboardingPage(
            title: "History View",
            content: "The History tab shows a chronological record of all logged items. Filter by date, item, or category. Admins can edit timestamps or delete logs if needed. Add logs to past days for items that were consumed but not logged by clicking the + button and entering details.",
            imageName: "history-video"
        ),
        OnboardingPage(
            title: "Editing Your Plan",
            content: "Admins can modify the treatment plan through Settings > Edit Plan. Here you can update cycle details, add/edit items, create groups, and manage units of measurement. Changes sync automatically to all users with access to your room.",
            imageName: "edit-plan-video"
        ),
        OnboardingPage(
            title: "Managing Items",
            content: "Items are organized by category: Medicine, Maintenance, Treatment, and Recommended. Treatment foods have the option to enter special weekly dosing schedules that automatically adjust as your cycle progresses. Add items through Settings > Edit Plan > Edit Items.",
            imageName: "items-video"
        ),
        OnboardingPage(
            title: "Create Groups",
            content: "Group related items together to log them simultaneously. For example, group 'Muffin' with its ingredients like 'Egg' and 'Milk'. Create groups in Settings > Edit Plan > Edit Grouped Items. Check a group to log all items at once. Click the group name to show the items contained within the group",
            imageName: "groups-video"
        ),
        OnboardingPage(
            title: "Dose Reminders",
            content: "Enable daily reminders for each category in Settings > Notifications. If items in a category aren't logged by your selected time, you'll receive a notification. Customize times for each category based on your daily routine.",
            imageName: "reminders-video"
        ),
        OnboardingPage(
            title: "Timer Notifications",
            content: "When you log a treatment food, a 15-minute timer automatically starts. This helps you space the administration of treatment doses. Enable notifications in Settings to get alerts when the timer ends.",
            imageName: "timer-video"
        )
    ]
    
    init(isShowingOnboarding: Binding<Bool>) {
        self._isShowingOnboarding = isShowingOnboarding
        // Initialize players for all video pages
        var initialPlayers: [Int: AVPlayer] = [:]
        for (index, page) in pages.enumerated() where index > 0 { // Skip first page (graphic)
            if let videoURL = Bundle.main.url(forResource: page.imageName, withExtension: "mp4") {
                let player = AVPlayer(url: videoURL)
                initialPlayers[index] = player
            }
        }
        self._players = State(initialValue: initialPlayers)
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header with Back/Next buttons
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                self.currentPage -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .padding()
                        }
                    } else {
                        Spacer()
                            .frame(width: 80)
                    }
                    
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        Button(action: {
                            withAnimation {
                                self.currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                        }
                    } else {
                        Button(action: {
                            isShowingOnboarding = false
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Get Started")
                                .bold()
                                .padding()
                        }
                    }
                }
                .padding(.horizontal)
                
                // Page title
                Text(pages[currentPage].title)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                
                // Page content
                ScrollView {
                    VStack(spacing: 20) {
                        // Custom content for first page (Understanding Cycles)
                        if currentPage == 0 {
                            // Graphic
                            if let image = UIImage(named: "cycle-graphic") {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                    .accessibilityLabel("Timeline of a treatment cycle showing Dosing Start Date, Cycle Number, and Food Challenge Date")
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .cornerRadius(12)
                                    Text("Graphic not found")
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Bullet points with proper alignment
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    Text("•")
                                    VStack(alignment: .leading) {
                                        Text("Room:")
                                            .fontWeight(.bold)
                                        Text("The place for all things related to an individual particiapnt. A Room contains all cycle data for a single participant. Users can have access to and manage multiple Rooms if they are involved with multiple participants.")
                                            .fixedSize(horizontal: false, vertical: true)
                                            .accessibilityLabel("Room: The place for all things related to an individual particiapnt. A Room contains all cycle data for a single participant. Users can have access to and manage multiple Rooms if they are involved with multiple participants.")
                                    }
                                }
                                HStack(alignment: .top) {
                                    Text("•")
                                    VStack(alignment: .leading) {
                                        Text("Cycle:")
                                            .fontWeight(.bold)
                                        Text("The current round of treatment foods the participant is working on")
                                            .fixedSize(horizontal: false, vertical: true)
                                            .accessibilityLabel("Cycle: The current round of treatment foods the participant is working on")
                                    }
                                }
                                HStack(alignment: .top) {
                                    Text("•")
                                    VStack(alignment: .leading) {
                                        Text("Cycle Number:")
                                            .fontWeight(.bold)
                                        Text("Cycle Number: What round of treatment foods the participant is working on. Example: Launch visit --> visit 1 = cycle 1. Visit 2 --> visit 3 = cycle 3")
                                            .fixedSize(horizontal: false, vertical: true)
                                            .accessibilityLabel("Cycle Number: What round of treatment foods the participant is working on. Example: Launch visit to visit 1 is cycle 1. Visit 2 to visit 3 is cycle 3.")
                                    }
                                }
                                HStack(alignment: .top) {
                                    Text("•")
                                    VStack(alignment: .leading) {
                                        Text("Dosing Start Date:")
                                            .fontWeight(.bold)
                                        Text("The first day the treatment foods were dosed in the cycle")
                                            .fixedSize(horizontal: false, vertical: true)
                                            .accessibilityLabel("Dosing Start Date: The first day the treatment foods were dosed in the cycle")
                                    }
                                }
                                HStack(alignment: .top) {
                                    Text("•")
                                    VStack(alignment: .leading) {
                                        Text("Food Challenge Date:")
                                            .fontWeight(.bold)
                                        Text("The date the cycle treatment foods will be challenged")
                                            .fixedSize(horizontal: false, vertical: true)
                                            .accessibilityLabel("Food Challenge Date: The date the cycle treatment foods will be challenged")
                                    }
                                }
                            }
                            .font(.body)
                            .padding(.horizontal)
                        } else {
                            // Video player for other pages
                            if let player = players[currentPage] {
                                VideoPlayer(player: player)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 300)
                                    .clipped()
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                    .accessibilityLabel("Video explaining \(pages[currentPage].title)")
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .cornerRadius(12)
                                    Text("Video not found")
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Content text
                        Text(pages[currentPage].content)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                }
                
                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom)
                
                // Skip button at bottom
                if currentPage < pages.count - 1 {
                    Button(action: {
                        isShowingOnboarding = false
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Skip All")
                            .foregroundColor(.secondary)
                            .padding(.bottom)
                    }
                }
            }
        }
        .onAppear {
            // Start first video if on a video page
            if currentPage > 0, let player = players[currentPage] {
                print("Playing video for page \(currentPage): \(pages[currentPage].imageName)")
                player.seek(to: .zero)
                player.play()
            }
        }
        .onChange(of: currentPage) { oldPage, newPage in
            print("Page changed from \(oldPage) to \(newPage)")
            // Pause all players
            players.forEach { index, player in
                player.pause()
                print("Paused player for page \(index)")
            }
            
            // Play video for new page if it exists
            if newPage > 0, let player = players[newPage] {
                print("Playing video for page \(newPage): \(pages[newPage].imageName)")
                player.seek(to: .zero)
                player.play()
            } else {
                print("No video to play for page \(newPage)")
            }
        }
        .onDisappear {
            // Clean up all players
            players.forEach { $0.value.pause() }
            players.removeAll()
            print("Onboarding view disappeared, cleaned up players")
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 && currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else if value.translation.width > 50 && currentPage > 0 {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }
        )
    }
}

struct OnboardingPage {
    let title: String
    let content: String
    let imageName: String
}

struct OnboardingTutorialButton: View {
    @Binding var isShowingOnboarding: Bool
    
    var body: some View {
        Button(action: {
            isShowingOnboarding = true
        }) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("View Tutorial")
                    .font(.headline)
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isShowingOnboarding: .constant(true))
    }
}
