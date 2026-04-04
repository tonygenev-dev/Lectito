//
//  ContentView.swift
//  Lectito
//
//  Created by Tony on 04/04/2026.
//

import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case home, library }
    enum Feed: String, CaseIterable, Identifiable { case forYou = "For you"; case trending = "Trending"; var id: Self { self } }

    @State private var selectedTab: Tab = .home
    @State private var feed: Feed = .forYou
    @State private var query: String = ""
    @State private var isShowingSearch: Bool = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Home Tab
                NavigationStack {
                    HomeFeedView(feed: $feed)
                        .navigationTitle("Lectito")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

                // Library Tab
                NavigationStack {
                    LibraryView()
                        .navigationTitle("Library")
                }
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(Tab.library)
            }

            // Floating Search button anchored bottom-right
            VStack { Spacer()
                HStack { Spacer()
                    Button {
                        isShowingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(16)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.12))
                    )
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                    .padding(.trailing, 16)
                    .padding(.bottom, 24) // lift above the tab bar
                    .accessibilityLabel("Search")
                }
            }
        }
        .sheet(isPresented: $isShowingSearch) {
            NavigationStack {
                SearchView(query: $query)
                    .navigationTitle("Search")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isShowingSearch = false }
                        }
                    }
            }
        }
    }
}

// MARK: - Home Feed
private struct HomeFeedView: View {
    @Binding var feed: ContentView.Feed
    @State private var showingProfile = false // Controls the profile sheet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Greeting & Profile Picture (Matches your screenshot)
                HStack(alignment: .bottom) {
                    Text("Hello, ")
                        .font(.largeTitle.bold()) +
                    Text("Kyran")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.indigo) // The purple tint
                    Text("!")
                        .font(.largeTitle.bold())
                    
                    Spacer()
                    
                    Button {
                        showingProfile = true
                    } label: {
                        // Replace "profile_pic" with your actual image asset name
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.top, 4)

                // Segmented control
                Picker("Feed", selection: $feed) {
                    ForEach(ContentView.Feed.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                // Cards
                LazyVStack(spacing: 16) {
                    ForEach(SampleData.articles) { article in
                        ArticleCard(article: article)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        // Present the Profile View as a modal sheet
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                ProfileView()
            }
        }
    }
}
// MARK: - Library View
private struct LibraryView: View {
    // Mock state for user's custom folders
    @State private var customFolders: [ArticleFolder] = [
        ArticleFolder(name: "Design Inspiration", count: 12, icon: "folder"),
        ArticleFolder(name: "Psychology Deep Dives", count: 5, icon: "folder"),
        ArticleFolder(name: "To Read Later", count: 24, icon: "tray.full")
    ]
    
    var body: some View {
        List {
            // Section 1: Standard Apple Music-style static categories
            Section {
                NavigationLink(value: "All Saved") {
                    Label {
                        Text("All Saved")
                    } icon: {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(.blue)
                    }
                }
                
                NavigationLink(value: "Favorites") {
                    Label {
                        Text("Favorites")
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            
            // Section 2: Custom Folders (Like Playlists)
            Section {
                ForEach(customFolders) { folder in
                    NavigationLink(value: folder.name) {
                        HStack {
                            Image(systemName: folder.icon)
                                .foregroundStyle(.secondary)
                            
                            Text(folder.name)
                            
                            Spacer()
                            
                            Text("\(folder.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                // Optional: Allow swipe to delete for folders
                .onDelete { indexSet in
                    customFolders.remove(atOffsets: indexSet)
                }
            } header: {
                HStack {
                    Text("My Folders")
                    Spacer()
                    Button {
                        // Action to create a new folder
                        print("Create new folder tapped")
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
        .listStyle(.insetGrouped) // This gives it the native Apple Music look
        // Setup dummy navigation destinations for now
        .navigationDestination(for: String.self) { folderName in
            Text("\(folderName) Contents")
                .navigationTitle(folderName)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Model for the Folders
private struct ArticleFolder: Identifiable {
    let id = UUID()
    var name: String
    var count: Int
    var icon: String
}
// MARK: - Article Model & Sample Data
private struct Article: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let topic: String
    let minutes: Int
    let imageSystemName: String
}

private enum SampleData {
    static let articles: [Article] = [
        Article(title: "The Art of Listening", subtitle: "Listening Skills Exercises", topic: "Social Psychology", minutes: 5, imageSystemName: "photo"),
        Article(title: "The Ideal Design Workflow", subtitle: "Reduce chaos to create process people love", topic: "Design & Media Creation", minutes: 7, imageSystemName: "photo"),
        Article(title: "How to develop an eye for Design", subtitle: "When I started off in design, I sucked.", topic: "Design", minutes: 4, imageSystemName: "photo"),
        Article(title: "Sell Something Bigger Than Your Business", subtitle: "What your brand really sells.", topic: "Business & Marketing", minutes: 6, imageSystemName: "photo")
    ]
}

// MARK: - Article Card
private struct ArticleCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.15))
                    .frame(width: 86, height: 86)
                    .overlay(
                        Image(systemName: article.imageSystemName)
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(article.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text("Topic (") + Text(article.topic) + Text(")")
                        Text("•")
                        Text("\(article.minutes) min read")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack {
                Spacer()
                Button("Read Article") { }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.12))
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

// MARK: - Search View (reused in sheet)
private struct SearchView: View {
    @Binding var query: String

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField("Search books, authors, ISBN…", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.horizontal)

            List {
                if query.isEmpty {
                    Text("Type to search")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Results for \"\(query)\"…")
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Profile & Insights View
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Subtitle
                Text("Your behaviour shapes what we recommend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, -10)
                
                // 1. Top Stat Cards
                HStack(spacing: 12) {
                    StatCard(icon: "book", value: "13", label: "ARTICLES", color: .red)
                    StatCard(icon: "clock", value: "2", label: "MINUTES", color: .teal)
                    StatCard(icon: "eye", value: "5", label: "DEEP READS", color: .indigo)
                }
                
                // 2. Category Rankings
                VStack(alignment: .leading, spacing: 20) {
                    Text("Category Rankings")
                        .font(.title3.bold())
                    
                    RankingRow(icon: "cpu", title: "Technology", points: 187, color: .blue, progress: 0.9)
                    RankingRow(icon: "flask", title: "Science", points: 185, color: .indigo, progress: 0.88)
                    RankingRow(icon: "leaf", title: "Environment", points: 112, color: .green, progress: 0.5)
                    RankingRow(icon: "brain.head.profile", title: "Psychology", points: 76, color: .orange, progress: 0.3)
                }
                .padding()
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
                
                // 3. How Points Work
                VStack(alignment: .leading, spacing: 20) {
                    Text("How Points Work")
                        .font(.title3.bold())
                    
                    InfoRow(icon: "bolt.fill", title: "Short-term Points", desc: "Reflect your current interests. Based on reading speed, scroll depth, and re-engagement. These shape your daily recommendations.", color: .orange)
                    
                    InfoRow(icon: "chart.xyaxis.line", title: "Long-term (Resume) Points", desc: "Represent your enduring interests. Accumulate over time from deep reads and completions. These define your reader identity.", color: .indigo)
                }
                .padding()
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
                
                // 4. Settings & Sign Out
                VStack(spacing: 0) {
                    NavigationLink {
                        Text("Settings Screen")
                            .navigationTitle("Settings")
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .foregroundStyle(.primary)
                    }
                    
                    Divider().padding(.leading, 40)
                    
                    Button(role: .destructive) {
                        // Add Sign Out Logic Here
                        print("Signed out")
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                            Spacer()
                        }
                        .padding()
                    }
                }
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .background(Color(uiColor: .secondarySystemBackground)) // Light gray background
        .navigationTitle("Reading Insights")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Reusable Profile Components

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .kerning(1.2) // Adds slight letter spacing like in your screenshot
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RankingRow: View {
    let icon: String
    let title: String
    let points: Int
    let color: Color
    let progress: Double
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon in colored rounded square
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            
            VStack(spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text("\(points) pts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Custom Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(uiColor: .systemGray5))
                            .frame(height: 6)
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let desc: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true) // Prevents text truncation
            }
        }
    }
}

#Preview {
    ContentView()
}
