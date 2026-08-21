import SwiftUI
import SafariServices

struct ExamCalendarView: View {
    @Environment(SessionStore.self) private var session
    @State private var response: ExamCalendarResponse?
    @State private var city = "全部"
    @State private var followedOnly = false
    @State private var loading = false
    @State private var error: String?
    @State private var browserTarget: ExamBrowserTarget?
    @State private var selectedExam: RecruitmentExam?
    @State private var followedItems: [RecruitmentExam] = []
    @State private var followedCarouselIndex = 0

    var body: some View {
        ZStack {
            TijingPageBackground()
            ScrollView {
                LazyVStack(spacing: 16) {
                    filterBar

                    if session.isAuthenticated {
                        followedCarousel
                    }

                    if !filteredItems.isEmpty {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, exam in
                            examCard(exam, index: index)
                        }
                    } else if !loading {
                        TijingPaperCard(tint: TijingDesign.sky) {
                            HStack(spacing: 12) {
                                TijingStickerIcon(systemImage: "calendar", tint: TijingDesign.cyan, background: TijingDesign.sky, size: 42, sparkle: false)
                                Text(error ?? "当前筛选范围暂无考试信息")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            if loading && response == nil { ProgressView("正在同步日历") }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.isAuthenticated) { await load() }
        .task(id: followedItems.map(\.id)) { await runFollowedCarousel() }
        .refreshable { await load() }
        .sensoryFeedback(.selection, trigger: city)
        .sensoryFeedback(.selection, trigger: followedOnly)
        .sheet(item: $selectedExam) { exam in
            ExamDetailSheet(exam: exam)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $browserTarget) { target in
            ExamInAppBrowser(url: target.url)
                .ignoresSafeArea()
        }
    }

    private var filteredItems: [RecruitmentExam] {
        guard let items = response?.items else { return [] }
        return items.filter { exam in
            let matchesCity = city == "全部" || exam.city == city || exam.region == city
            let matchesFollow = !followedOnly || exam.followed == true
            return matchesCity && matchesFollow
        }
    }

    private var availableCities: [ExamCity] {
        if let cities = response?.cities, !cities.isEmpty { return cities }

        let counts = Dictionary(grouping: response?.items ?? [], by: { $0.city ?? $0.region ?? "" })
            .filter { !$0.key.isEmpty }
            .map { ExamCity(name: $0.key, count: $0.value.count) }
        return counts.sorted { lhs, rhs in
            if lhs.count == rhs.count { return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
            return lhs.count > rhs.count
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("筛选", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if response != nil {
                    let count = filteredItems.count
                    Text("\(count) 场")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            HStack(spacing: 9) {
                Menu {
                    Button {
                        withAnimation(.snappy(duration: 0.28)) { city = "全部" }
                    } label: {
                        Label("全部地区", systemImage: city == "全部" ? "checkmark" : "location")
                    }

                    if !availableCities.isEmpty {
                        Divider()
                    }

                    ForEach(availableCities) { item in
                        Button {
                            withAnimation(.snappy(duration: 0.28)) { city = item.name }
                        } label: {
                            HStack {
                                Text("\(item.name)（\(item.count)）")
                                if city == item.name { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    filterChip(
                        title: city == "全部" ? "全部地区" : city,
                        systemImage: "location.fill",
                        selected: city != "全部",
                        tint: TijingDesign.indigo,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.snappy(duration: 0.28)) { followedOnly.toggle() }
                    Haptics.selection()
                } label: {
                    filterChip(
                        title: "只看关注",
                        systemImage: followedOnly ? "star.fill" : "star",
                        selected: followedOnly,
                        tint: TijingDesign.amber
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if city != "全部" || followedOnly {
                    Button {
                        withAnimation(.snappy(duration: 0.28)) {
                            city = "全部"
                            followedOnly = false
                        }
                        Haptics.selection()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color.primary.opacity(0.045), in: Circle())
                    }
                    .buttonStyle(TijingPressableCardStyle())
                    .accessibilityLabel("清除筛选")
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055))
        }
        .shadow(color: Color.black.opacity(0.035), radius: 12, y: 6)
        .animation(.snappy(duration: 0.30), value: city)
        .animation(.snappy(duration: 0.30), value: followedOnly)
    }

    private func filterChip(
        title: String,
        systemImage: String,
        selected: Bool,
        tint: Color,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.62)
            }
        }
        .foregroundStyle(selected ? tint : Color.primary.opacity(0.76))
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(
            selected ? tint.opacity(0.13) : Color.primary.opacity(0.045),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(selected ? tint.opacity(0.16) : Color.primary.opacity(0.035))
        }
        .contentShape(Capsule())
    }

    private func examCard(_ exam: RecruitmentExam, index: Int) -> some View {
        let tint = [TijingDesign.sky, TijingDesign.sage, TijingDesign.lilac, TijingDesign.peach][index % 4]
        return TijingPaperCard(tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    TijingStickerIcon(systemImage: "calendar", tint: TijingDesign.ink.opacity(0.70), background: tint, size: 40, rotation: index.isMultiple(of: 2) ? -5 : 5, sparkle: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exam.title).font(.headline)
                        Text([exam.city, exam.examKind].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                        if let sourceName = exam.sourceName, !sourceName.isEmpty {
                            Text(sourceName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Button {
                        Haptics.selection()
                        toggleFollow(exam)
                    } label: {
                        Image(systemName: exam.followed == true ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(exam.followed == true ? TijingDesign.amber : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(exam.followed == true ? "取消关注\(exam.title)" : "关注\(exam.title)")
                }

                if let next = exam.nextLabel {
                    HStack(spacing: 8) {
                        TijingMicroBadge(title: next, systemImage: "calendar.badge.clock", tint: TijingDesign.indigo)
                        Spacer()
                        if let days = exam.daysToNext {
                            Text(days == 0 ? "今天" : "还有 \(days) 天")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }

                if let excerpt = exam.sourceExcerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let source = exam.sourceURL, let url = URL(string: source) {
                    Button {
                        Haptics.light()
                        browserTarget = ExamBrowserTarget(url: url)
                    } label: {
                        Label("查看官方来源", systemImage: "safari")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
        .onTapGesture {
            Haptics.selection()
            selectedExam = exam
        }
    }

    @ViewBuilder
    private var followedCarousel: some View {
        if followedItems.isEmpty {
            EmptyView()
        } else {
            let safeIndex = min(followedCarouselIndex, max(0, followedItems.count - 1))
            let exam = followedItems[safeIndex]
            Button {
                Haptics.selection()
                selectedExam = exam
            } label: {
                TijingPaperCard(tint: TijingDesign.butter, rotation: -0.12) {
                    HStack(spacing: 13) {
                        TijingStickerIcon(systemImage: "star.fill", tint: TijingDesign.amber, background: TijingDesign.butter, size: 46, rotation: -6)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                Text("我的关注")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(TijingDesign.amber)
                                if followedItems.count > 1 {
                                    Text("\(safeIndex + 1)/\(followedItems.count)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Text(exam.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                if let label = exam.nextLabel, !label.isEmpty { Text(label) }
                                if let days = exam.daysToNext {
                                    if exam.nextLabel?.isEmpty == false { Text("·") }
                                    Text(days <= 0 ? "就在今天" : "还有 \(days) 天")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                }
                .id(exam.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .buttonStyle(TijingPressableCardStyle())
            .animation(.snappy(duration: 0.42), value: followedCarouselIndex)
        }
    }

    @MainActor
    private func runFollowedCarousel() async {
        guard followedItems.count > 1 else { followedCarouselIndex = 0; return }
        followedCarouselIndex = min(followedCarouselIndex, followedItems.count - 1)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, followedItems.count > 1 else { return }
            withAnimation(.snappy(duration: 0.42)) {
                followedCarouselIndex = (followedCarouselIndex + 1) % followedItems.count
            }
        }
    }

    @MainActor private func load() async {
        let path = session.token == nil ? "/api/exams/calendar" : "/api/exams/calendar/me"
        let owner = session.user.map { String($0.id) } ?? "public"
        let cacheKey = "calendar.\(owner).all"

        if response == nil { response = session.api.cachedResponse(for: cacheKey) }
        loading = response == nil
        defer { loading = false }
        do {
            response = try await session.api.requestCached(
                path, token: session.token, cacheKey: cacheKey
            )
            if let token = session.token {
                let followedQuery = [URLQueryItem(name: "followed_only", value: "true")]
                if let followedResponse: ExamCalendarResponse = try? await session.api.requestCached(
                    "/api/exams/calendar/me",
                    token: token,
                    query: followedQuery,
                    cacheKey: "calendar.\(owner).followed.carousel"
                ) {
                    followedItems = followedResponse.items.filter { $0.followed == true }
                    if followedCarouselIndex >= followedItems.count { followedCarouselIndex = 0 }
                }
            } else {
                followedItems = []
                followedCarouselIndex = 0
            }
            error = nil
        } catch {
            self.error = response == nil ? error.localizedDescription : nil
        }
    }

    private func toggleFollow(_ exam: RecruitmentExam) {
        guard let token = session.token else { error = "登录后才能关注考试"; return }
        Task { @MainActor in
            do {
                let method: HTTPMethod = exam.followed == true ? .delete : .post
                let _: FollowResponse = try await session.api.request("/api/exams/calendar/\(exam.id)/follow", method: method, body: EmptyBody(), token: token)
                Haptics.success(); await load()
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }
}

private struct FollowResponse: Decodable { let followed: Bool?; let examID: Int?; enum CodingKeys: String, CodingKey { case followed; case examID = "exam_id" } }
private struct ExamDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exam: RecruitmentExam
    @State private var browserTarget: ExamBrowserTarget?

    var body: some View {
        NavigationStack {
            ZStack {
                TijingPageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TijingPaperCard(tint: TijingDesign.butter, rotation: -0.18) {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack(spacing: 10) {
                                    TijingStickerIcon(systemImage: "calendar.badge.clock", tint: TijingDesign.amber, background: TijingDesign.butter, size: 44, rotation: -6, sparkle: false)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(exam.city ?? "四川")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(TijingDesign.amber)
                                        Text(exam.title)
                                            .font(.headline)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                if let source = exam.sourceName, !source.isEmpty {
                                    Label(source, systemImage: "building.columns")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        VStack(spacing: 0) {
                            detailRow("公告发布", value: exam.announcementDate, icon: "megaphone.fill", tint: TijingDesign.violet)
                            detailRow("报名开始", value: exam.registrationStart, icon: "play.circle.fill", tint: TijingDesign.mint)
                            detailRow("报名截止", value: exam.registrationEnd, icon: "stop.circle.fill", tint: TijingDesign.coral)
                            detailRow("缴费截止", value: exam.paymentDeadline, icon: "creditcard.fill", tint: TijingDesign.amber)
                            detailRow("准考证打印", value: dateRange(exam.admissionStart, exam.admissionEnd), icon: "doc.text.fill", tint: TijingDesign.indigo)
                            detailRow("笔试时间", value: exam.examDate, icon: "pencil.and.scribble", tint: TijingDesign.violet, showDivider: false)
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.primary.opacity(0.055)) }

                        if let excerpt = exam.sourceExcerpt, !excerpt.isEmpty {
                            TijingPaperCard(tint: TijingDesign.sky) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("公告摘要", systemImage: "text.alignleft")
                                        .font(.subheadline.weight(.semibold))
                                    Text(excerpt)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        if let source = exam.sourceURL, let url = URL(string: source) {
                            Button {
                                Haptics.light()
                                browserTarget = ExamBrowserTarget(url: url)
                            } label: {
                                Label("在应用内查看完整官方公告", systemImage: "safari.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TijingPrimaryButtonStyle())
                        }
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("考试详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(item: $browserTarget) { target in ExamInAppBrowser(url: target.url).ignoresSafeArea() }
        }
    }

    @ViewBuilder
    private func detailRow(_ title: String, value: String?, icon: String, tint: Color, showDivider: Bool = true) -> some View {
        if let value, !value.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 10)
                Text(value.contains(" ~ ") ? value : TijingFormat.examDateTime(value))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            if showDivider { Divider().padding(.leading, 60) }
        }
    }

    private func dateRange(_ start: String?, _ end: String?) -> String? {
        if let start, let end, start != end { return "\(TijingFormat.examDateTime(start)) ~ \(TijingFormat.examDateTime(end))" }
        if let start { return TijingFormat.examDateTime(start) }
        if let end { return TijingFormat.examDateTime(end) }
        return nil
    }
}

private struct ExamBrowserTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ExamInAppBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = .systemIndigo
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

