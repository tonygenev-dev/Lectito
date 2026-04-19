import SwiftUI
import Combine
import Supabase

// MARK: - Supabase Article Model
struct Article: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let topic: String
    let minutes: Int
    let imageSystemName: String
    
    var content: String?
    var author: String?
    var imageUrl: String?
    var contentImageUrl: String?
    
    static func ==(lhs: Article, rhs: Article) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - THE AI: Interest Manager
class InterestManager: ObservableObject {
    @AppStorage("userInterestProfile") private var profileData: Data = Data()
    @AppStorage("savedArticlesData") private var savedArticlesData: Data = Data()
    
    @Published var topicScores: [String: Int] = [:]
    @Published var savedArticles: [Article] = []
    
    init() { loadData() }
    
    private func loadData() {
        if let decoded = try? JSONDecoder().decode([String: Int].self, from: profileData) {
            topicScores = decoded
        } else {
            topicScores = ["Technology": 5, "Science": 3, "Psychology": 2, "Environment": 0, "Design": 0]
        }
        
        if let decodedSaved = try? JSONDecoder().decode([Article].self, from: savedArticlesData) {
            savedArticles = decodedSaved
        }
    }
    
    private func saveData() {
        if let encodedScores = try? JSONEncoder().encode(topicScores) { profileData = encodedScores }
        if let encodedBookmarks = try? JSONEncoder().encode(savedArticles) { savedArticlesData = encodedBookmarks }
    }
    
    func recordAction(action: ActionType, for topic: String) {
        let points: Int
        switch action {
        case .readArticle: points = 3
        case .bookmark: points = 15
        case .quickExit: points = -2
        }
        
        let currentScore = topicScores[topic] ?? 0
        topicScores[topic] = max(0, currentScore + points)
        saveData()
    }
    
    func sortForYou(articles: [Article]) -> [Article] {
        return articles.sorted { first, second in
            let firstScore = topicScores[first.topic] ?? 0
            let secondScore = topicScores[second.topic] ?? 0
            return firstScore > secondScore
        }
    }
    
    func toggleBookmark(for article: Article) {
        if let index = savedArticles.firstIndex(where: { $0.id == article.id }) {
            savedArticles.remove(at: index)
        } else {
            savedArticles.append(article)
            recordAction(action: .bookmark, for: article.topic)
        }
        saveData()
    }
    
    func isBookmarked(_ article: Article) -> Bool {
        savedArticles.contains(where: { $0.id == article.id })
    }
    
    func resetDemo() {
        topicScores = ["Technology": 5, "Science": 3, "Psychology": 2, "Environment": 0, "Design": 0]
        savedArticles.removeAll()
        saveData()
    }
    
    enum ActionType { case readArticle, bookmark, quickExit }
}

// MARK: - Main Content View
struct ContentView: View {
    private enum Tab: Hashable { case home, library }
    enum Feed: String, CaseIterable, Identifiable { case forYou = "For you"; case trending = "Trending"; var id: Self { self } }

    @State private var selectedTab: Tab = .home
    @State private var feed: Feed = .forYou
    @State private var query: String = ""
    @State private var isShowingSearch: Bool = false
    
    // Lifted state so both HomeFeed and Search can access the articles!
    @State private var articles: [Article] = []
    @State private var isLoading = true
    
    @StateObject private var aiEngine = InterestManager()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeFeedView(feed: $feed, articles: articles, isLoading: isLoading)
                        .navigationTitle("Lectito")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

                NavigationStack {
                    LibraryView()
                        .navigationTitle("Library")
                }
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(Tab.library)
            }

            VStack { Spacer()
                HStack { Spacer()
                    Button { isShowingSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .semibold)).padding(16)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12)))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                    .padding(.trailing, 16).padding(.bottom, 24)
                }
            }
        }
        .environmentObject(aiEngine)
        .task { await fetchArticles() }
        .sheet(isPresented: $isShowingSearch) {
            NavigationStack {
                SearchView(query: $query, articles: articles)
                    .navigationTitle("Search")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { isShowingSearch = false } } }
            }
            .environmentObject(aiEngine) // Ensure search sheet gets AI engine
        }
    }
    
    // Centralized Fetch
    private func fetchArticles() async {
        if !articles.isEmpty { return } // Prevent refetching unnecessarily
        do {
            let downloaded: [Article] = try await supabase.from("Articles").select().execute().value
            if !downloaded.isEmpty {
                await MainActor.run { self.articles = downloaded; self.isLoading = false }
                return
            }
        } catch { print("Using Demo Data.") }
        
        await MainActor.run {
            self.articles = DemoData.articles
            self.isLoading = false
        }
    }
}

// MARK: - Home Feed
private struct HomeFeedView: View {
    @Binding var feed: ContentView.Feed
    @State private var showingProfile = false
    @State private var selectedArticle: Article? = nil
    
    let articles: [Article]
    let isLoading: Bool
    
    @EnvironmentObject var aiEngine: InterestManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    Text("Hello, ").font(.largeTitle.bold()) + Text("Kyran").font(.largeTitle.bold()).foregroundStyle(Color.indigo) + Text("!").font(.largeTitle.bold())
                    Spacer()
                    Button { showingProfile = true } label: {
                        Image(systemName: "person.crop.circle.fill").resizable().scaledToFill().frame(width: 44, height: 44).clipShape(Circle()).foregroundStyle(.gray)
                    }
                }
                .padding(.top, 4)

                Picker("Feed", selection: $feed) {
                    ForEach(ContentView.Feed.allCases) { option in Text(option.rawValue).tag(option) }
                }.pickerStyle(.segmented)

                if isLoading {
                    ProgressView("AI Curating Feed...").frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(feed == .forYou ? aiEngine.sortForYou(articles: articles) : articles) { article in
                            ArticleCard(article: article) {
                                aiEngine.recordAction(action: .readArticle, for: article.topic)
                                selectedArticle = article
                            }
                        }
                    }.padding(.top, 4)
                }
            }
            .padding(.horizontal).padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingProfile) { NavigationStack { ProfileView() } }
        .fullScreenCover(item: $selectedArticle) { article in
            NavigationStack { ArticleDetailView(article: article) }
                .environmentObject(aiEngine)
        }
    }
}

// MARK: - Article Card
private struct ArticleCard: View {
    let article: Article
    let onRead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 86, height: 86)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.15)).frame(width: 86, height: 86)
                        .overlay(Image(systemName: article.imageSystemName).font(.system(size: 28)).foregroundStyle(.secondary))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                    Text(article.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    HStack(spacing: 6) {
                        Text("Topic (") + Text(article.topic) + Text(")")
                        Text("•")
                        Text("\(article.minutes) min read")
                    }.font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Spacer()
                Button(action: onRead) {
                    Text("Read Article").font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10).background(Capsule().fill(Color.accentColor)).foregroundStyle(.white)
                }
            }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12))).shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

// MARK: - Article Detail View
// MARK: - Article Detail View
struct ArticleDetailView: View {
    let article: Article
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var aiEngine: InterestManager
    
    @State private var scrollProgress: CGFloat = 0.0
    @State private var timeOpened: Date? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            
            // 1. THE SCROLLING ARTICLE & PROGRESS BAR
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Header Image
                        ZStack(alignment: .topTrailing) {
                            if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Rectangle().fill(Color.gray.opacity(0.2)) }
                            } else {
                                ZStack {
                                    LinearGradient(colors: [.indigo.opacity(0.6), .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    Image(systemName: article.imageSystemName).font(.system(size: 60)).foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }
                        .frame(height: 300)
                        .clipped()
                        .padding(.bottom, 16)
                        
                        // Article Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text(article.title).font(.largeTitle.bold())
                            Text(article.subtitle).font(.title3).foregroundStyle(.secondary)
                            Text("\(article.author ?? "Lectito Author") | \(article.minutes) min read").font(.subheadline).foregroundStyle(.gray).padding(.bottom, 12).padding(.top, 4)
                            
                            Text(DemoData.loremIpsumPart1).font(.body).lineSpacing(6)
                            
                            if let contentImg = article.contentImageUrl, let url = URL(string: contentImg) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.1))
                                }
                                .frame(height: 220)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.vertical, 12)
                            }
                            
                            Text(DemoData.loremIpsumPart2).font(.body).lineSpacing(6)
                            Spacer().frame(height: 150)
                        }.padding(.horizontal, 20)
                    }
                    .background(
                        GeometryReader { geo -> Color in
                            DispatchQueue.main.async {
                                let scrollOffset = -geo.frame(in: .named("scrollSpace")).minY
                                let maxScroll = geo.size.height - UIScreen.main.bounds.height + 100
                                if maxScroll > 0 { self.scrollProgress = min(max(scrollOffset / maxScroll, 0), 1) }
                            }
                            return Color.clear
                        }
                    )
                }
                .coordinateSpace(name: "scrollSpace")
                .ignoresSafeArea(edges: .top)
                
                // Progress Bar
                VStack {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.2)).frame(height: 4)
                            Capsule().fill(Color.blue).frame(width: geo.size.width * scrollProgress, height: 4)
                            Circle().fill(Color.blue).frame(width: 8, height: 8).offset(x: (geo.size.width * scrollProgress) - 4)
                        }
                    }.frame(height: 8).padding(.horizontal, 24).padding(.bottom, 16)
                }.background(Rectangle().fill(.ultraThinMaterial).mask(LinearGradient(colors: [.white, .clear], startPoint: .bottom, endPoint: .top)).ignoresSafeArea())
            }
            
            // 2. FLOATING LIQUID GLASS BUTTONS
            HStack {
                // Back Button
                Button {
                    if let openTime = timeOpened, Date().timeIntervalSince(openTime) < 3.0 {
                        aiEngine.recordAction(action: .quickExit, for: article.topic)
                    }
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .offset(x: -1.5) // Optical center fix
                        .frame(width: 44, height: 44)
                        // The Liquid Glass Effect
                        .background(Circle().fill(.ultraThinMaterial).opacity(0.85)) // Base blur
                        .background(Circle().fill(Color.white.opacity(0.15))) // Watery clear tint
                        .overlay(
                            Circle().stroke(
                                // Diagonal light reflection
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .clear, .white.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Bookmark Button
                Button {
                    aiEngine.toggleBookmark(for: article)
                } label: {
                    Image(systemName: aiEngine.isBookmarked(article) ? "bookmark.fill" : "bookmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(aiEngine.isBookmarked(article) ? .blue : .primary)
                        .frame(width: 44, height: 44)
                        // The Liquid Glass Effect
                        .background(Circle().fill(.ultraThinMaterial).opacity(0.85))
                        .background(Circle().fill(Color.white.opacity(0.15)))
                        .overlay(
                            Circle().stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .clear, .white.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
            }
            // CHANGED: Increased from 16 to 24 to push the buttons inward from the edges
            .padding(.horizontal, 24)
            .padding(.top, 56)
            
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { timeOpened = Date() }
    }
}

// MARK: - Library View
private struct LibraryView: View {
    @EnvironmentObject var aiEngine: InterestManager
    var body: some View {
        List {
            Section {
                NavigationLink(destination: SavedArticlesView()) {
                    HStack {
                        Label("All Saved", systemImage: "bookmark.fill").foregroundStyle(.blue)
                        Spacer()
                        Text("\(aiEngine.savedArticles.count)").foregroundStyle(.secondary)
                    }
                }
                NavigationLink(destination: Text("Favorites (Coming Soon)")) { Label("Favorites", systemImage: "heart.fill").foregroundStyle(.red) }
            }
            Section {
                NavigationLink(destination: Text("Contents")) { HStack { Image(systemName: "folder").foregroundStyle(.secondary); Text("Design Inspiration") } }
                NavigationLink(destination: Text("Contents")) { HStack { Image(systemName: "folder").foregroundStyle(.secondary); Text("Psychology Deep Dives") } }
            } header: { HStack { Text("My Folders"); Spacer(); Image(systemName: "plus").foregroundStyle(Color.accentColor) } }
        }.listStyle(.insetGrouped)
    }
}

struct SavedArticlesView: View {
    @EnvironmentObject var aiEngine: InterestManager
    var body: some View {
        ScrollView {
            if aiEngine.savedArticles.isEmpty {
                Text("No saved articles yet. Go bookmark some!").foregroundStyle(.secondary).padding(.top, 50)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(aiEngine.savedArticles) { article in
                        NavigationLink(destination: ArticleDetailView(article: article)) {
                            ArticleCard(article: article) { }
                        }.buttonStyle(.plain)
                    }
                }.padding()
            }
        }
        .navigationTitle("All Saved")
    }
}

// MARK: - Profile & Insights View
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var aiEngine: InterestManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Your behaviour shapes what we recommend")
                    .font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, -10)
                
                HStack(spacing: 12) {
                    StatCard(icon: "book", value: "\(aiEngine.savedArticles.count)", label: "SAVED", color: .red)
                    StatCard(icon: "clock", value: "14", label: "MINUTES", color: .teal)
                    StatCard(icon: "eye", value: "8", label: "DEEP READS", color: .indigo)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Category Rankings").font(.title3.bold())
                    
                    let sortedTopics = aiEngine.topicScores.sorted { $0.value > $1.value }
                    let highestScore = max(Double(sortedTopics.first?.value ?? 1), 1.0)
                    
                    ForEach(sortedTopics, id: \.key) { topic, score in
                        RankingRow(icon: getIcon(for: topic), title: topic, points: score, color: getColor(for: topic), progress: Double(score) / highestScore)
                    }
                }
                .padding().background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("How Points Work").font(.title3.bold())
                    InfoRow(icon: "bolt.fill", title: "Short-term Points", desc: "Reflect your current interests. Based on reading speed, scroll depth, and re-engagement.", color: .orange)
                    InfoRow(icon: "chart.xyaxis.line", title: "Long-term Points", desc: "Represent your enduring interests. Accumulate over time from deep reads.", color: .indigo)
                }
                .padding().background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
                
                Button {
                    aiEngine.resetDemo()
                } label: {
                    Text("Reset Demo Points (Invisible to real users)")
                        .font(.caption).foregroundStyle(.red)
                }
                .padding(.top, 10)
                
            }.padding()
        }.background(Color(uiColor: .secondarySystemBackground)).navigationTitle("Reading Insights").navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
    
    func getIcon(for topic: String) -> String {
        switch topic.lowercased() { case "technology": return "cpu"; case "science": return "flask"; case "psychology": return "brain.head.profile"; case "environment": return "leaf"; case "design": return "paintbrush.pointed"; default: return "book" }
    }
    
    func getColor(for topic: String) -> Color {
        switch topic.lowercased() { case "technology": return .blue; case "science": return .indigo; case "psychology": return .orange; case "environment": return .green; case "design": return .pink; default: return .gray }
    }
}

// MARK: - Reusable UI
private struct StatCard: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View { VStack(spacing: 8) { Image(systemName: icon).font(.title2).foregroundStyle(color); Text(value).font(.title.bold()); Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary).kerning(1.2) }.frame(maxWidth: .infinity).padding(.vertical, 16).background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16)) }
}
private struct RankingRow: View {
    let icon: String; let title: String; let points: Int; let color: Color; let progress: Double
    var body: some View { HStack(spacing: 16) { Image(systemName: icon).foregroundStyle(color).frame(width: 40, height: 40).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10)); VStack(spacing: 8) { HStack { Text(title).font(.headline); Spacer(); Text("\(points) pts").font(.subheadline).foregroundStyle(.secondary) }; GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color(uiColor: .systemGray5)).frame(height: 6); Capsule().fill(color).frame(width: geo.size.width * progress, height: 6) } }.frame(height: 6) } } }
}
private struct InfoRow: View {
    let icon: String; let title: String; let desc: String; let color: Color
    var body: some View { HStack(alignment: .top, spacing: 16) { Image(systemName: icon).foregroundStyle(color).frame(width: 40, height: 40).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(desc).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) } } }
}

// MARK: - SEARCH ENGINE VIEW
private struct SearchView: View {
    @Binding var query: String
    let articles: [Article] // Passed in from ContentView
    
    @EnvironmentObject var aiEngine: InterestManager
    @State private var selectedArticle: Article? = nil
    
    // The filtering logic!
    var searchResults: [Article] {
        if query.isEmpty { return [] }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.topic.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField("Search titles, topics...", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(12).background(.ultraThinMaterial).clipShape(Capsule()).padding(.horizontal)
            
            // Search Results
            List {
                if query.isEmpty {
                    Text("Type a topic (like 'Science') or title to search...")
                        .foregroundStyle(.secondary)
                } else if searchResults.isEmpty {
                    Text("No results found for \"\(query)\"")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(searchResults) { article in
                        Button {
                            // AI still learns from searches!
                            aiEngine.recordAction(action: .readArticle, for: article.topic)
                            selectedArticle = article
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title).font(.headline).foregroundStyle(.primary)
                                HStack {
                                    Text(article.topic)
                                    Text("•")
                                    Text("\(article.minutes) min read")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .fullScreenCover(item: $selectedArticle) { article in
            NavigationStack { ArticleDetailView(article: article) }
                .environmentObject(aiEngine) // Ensure full screen cover gets AI
        }
    }
}

// MARK: - DEMO DATA
struct DemoData {
    static let loremIpsumPart1 = """
    How you approach life says a lot about who you are. As I get deeper into my late 30s I have learned to focus more on experiences that bring meaning and fulfilment to my life. I try to consistently pursue life goals that will make me and my closest relations happy.
    
    Nothing gives a person inner wholeness and peace like a distinct understanding of where they are going, how they can get there, and a sense of control over their actions. This is why active listening is such a crucial skill.
    """
    
    static let loremIpsumPart2 = """
    In our fast-paced, digitally connected world, we are often distracted. We listen to respond, rather than listening to understand. True listening requires patience. Practice being present. Put away your phone. Make eye contact.
    
    Ultimately, the art of listening is the art of being human. It connects us, grounds us, and allows us to navigate the complexities of life with empathy and grace. Keep practicing, and you will see the profound impact it has on your personal and professional life.
    """
    
    static let articles: [Article] = [
        Article(id: UUID(uuidString: "A1111111-1111-1111-1111-111111111111")!, title: "The Future of AI in Daily Life", subtitle: "Beyond the hype.", topic: "Technology", minutes: 6, imageSystemName: "cpu", content: nil, author: "Elena Rostova", imageUrl: "https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=800&q=80", contentImageUrl: "https://images.unsplash.com/photo-1555255707-c07966088b7b?auto=format&fit=crop&w=800&q=80"),
        Article(id: UUID(uuidString: "B2222222-2222-2222-2222-222222222222")!, title: "The Psychology of Habit", subtitle: "Why we do what we do.", topic: "Psychology", minutes: 5, imageSystemName: "brain.head.profile", content: nil, author: "James Clear", imageUrl: "https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?auto=format&fit=crop&w=800&q=80", contentImageUrl: "https://images.unsplash.com/photo-1499209974431-9dddcece7f88?auto=format&fit=crop&w=800&q=80"),
        Article(id: UUID(uuidString: "C3333333-3333-3333-3333-333333333333")!, title: "Deep Sea Discoveries", subtitle: "What lies beneath the ocean.", topic: "Science", minutes: 8, imageSystemName: "flask", content: nil, author: "Sylvia Earle", imageUrl: "https://images.unsplash.com/photo-1532094349884-543bc11b234d?auto=format&fit=crop&w=800&q=80", contentImageUrl: "https://images.unsplash.com/photo-1582967788606-a171c1080cb0?auto=format&fit=crop&w=800&q=80"),
        Article(id: UUID(uuidString: "D4444444-4444-4444-4444-444444444444")!, title: "Rewilding the Earth", subtitle: "Nature's incredible comeback.", topic: "Environment", minutes: 7, imageSystemName: "leaf", content: nil, author: "David Attenborough", imageUrl: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=800&q=80", contentImageUrl: "https://images.unsplash.com/photo-1472214103451-9374bd1c798e?auto=format&fit=crop&w=800&q=80"),
        Article(id: UUID(uuidString: "E5555555-5555-5555-5555-555555555555")!, title: "Building Better Interfaces", subtitle: "Design systems that work.", topic: "Design", minutes: 4, imageSystemName: "desktopcomputer", content: nil, author: "Dieter Rams", imageUrl: "https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=800&q=80", contentImageUrl: "https://images.unsplash.com/photo-1561070791-2526d30994b5?auto=format&fit=crop&w=800&q=80"),
        Article(id: UUID(uuidString: "F6666666-6666-6666-6666-666666666666")!, title: "Overcoming Procrastination", subtitle: "Strategies for focus.", topic: "Psychology", minutes: 6, imageSystemName: "brain", content: nil, author: "Dr. Piers Steel", imageUrl: "https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=800&q=80", contentImageUrl: "https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?auto=format&fit=crop&w=800&q=80")
    ]
}

#Preview { ContentView() }

