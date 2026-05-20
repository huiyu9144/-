//
//  ContentView.swift
//  小进度
//
//  Created by huiyu on 2026/5/1.
//

import SwiftUI

struct Project: Identifiable, Equatable {
    let id: UUID
    var name: String
    var progress: Double
    var colorRGB: [Double]  // [r, g, b] 0-1
    
    var displayName: String {
        if name.isEmpty {
            return NSLocalizedString("new_project", comment: "New project placeholder")
        }
        return name
    }
    
    init(id: UUID = UUID(), name: String, progress: Double, colorRGB: [Double]? = nil) {
        self.id = id
        self.name = name
        self.progress = progress
        self.colorRGB = colorRGB ?? Project.randomLightColor()
    }
    
    static func randomLightColor(avoidingHues: [Double] = []) -> [Double] {
        // 生成适合黑色背景的浅色 (saturation: 0.6-1.0, brightness: 0.6-0.9)
        // avoidingHues: 需要避免的色相列表（0-1）
        
        let minHueDiff: Double = 0.15  // 最小色相差异（约54度）
        
        var hue: Double
        var attempts = 0
        let maxAttempts = 50
        
        repeat {
            hue = Double.random(in: 0...1)
            attempts += 1
        } while attempts < maxAttempts && avoidingHues.contains { existingHue in
            // 检查色相差异是否小于阈值（处理环形色相）
            let diff = abs(hue - existingHue)
            return diff < minHueDiff || (1 - diff) < minHueDiff
        }
        
        let saturation = Double.random(in: 0.6...1.0)
        let brightness = Double.random(in: 0.6...0.9)
        
        // HSB to RGB
        let h = hue * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        
        var r, g, b: Double
        switch Int(h) {
        case 0: r = c; g = x; b = 0
        case 1: r = x; g = c; b = 0
        case 2: r = 0; g = c; b = x
        case 3: r = 0; g = x; b = c
        case 4: r = x; g = 0; b = c
        case 5: r = c; g = 0; b = x
        default: r = 0; g = 0; b = 0
        }
        
        return [r + m, g + m, b + m]
    }
    
    var color: Color {
        Color(red: colorRGB[0], green: colorRGB[1], blue: colorRGB[2])
    }
    
    // 获取颜色的色相值（用于比较）
    var hue: Double {
        let r = colorRGB[0]
        let g = colorRGB[1]
        let b = colorRGB[2]
        
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        
        if max == min {
            return 0  // 灰色
        }
        
        let d = max - min
        var h: Double
        
        if max == r {
            h = ((g - b) / d).truncatingRemainder(dividingBy: 6)
        } else if max == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        
        return (h / 6).truncatingRemainder(dividingBy: 1)
    }
}

// Codable 支持，兼容旧数据
extension Project: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, progress, colorRGB
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        progress = try container.decode(Double.self, forKey: .progress)
        // 兼容旧数据：如果没有colorRGB就随机生成
        colorRGB = (try? container.decode([Double].self, forKey: .colorRGB)) ?? Project.randomLightColor()
    }
}

struct ContentView: View {
    @State private var projects: [Project] = []
    @State private var editingProjectId: UUID?
    @State private var editingName: String = ""
    @State private var isLoaded = false
    @State private var isEditingMode = false

    let defaults = UserDefaults.standard
    let projectsKey = "projects"
    
    var appTitle: String {
        NSLocalizedString("app_title", comment: "App title")
    }
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("hasSetTheme") private var hasSetTheme = false
    @Environment(\.colorScheme) private var colorScheme

    var isChineseLanguage: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }

    var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    func loadProjects() {
        if let data = defaults.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        } else {
            let defaultName1 = NSLocalizedString("project_1", comment: "Project 1 name")
            let defaultName2 = NSLocalizedString("project_2", comment: "Project 2 name")
            let defaultName3 = NSLocalizedString("project_3", comment: "Project 3 name")
            projects = [
                Project(name: defaultName1, progress: 30),
                Project(name: defaultName2, progress: 65),
                Project(name: defaultName3, progress: 90),
            ]
            saveProjects()
        }
    }

    func saveProjects() {
        if let data = try? JSONEncoder().encode(projects) {
            defaults.set(data, forKey: projectsKey)
        }
    }

    func addProject() {
        // 获取相邻项目的色相，确保新颜色与它们差异较大
        var avoidingHues: [Double] = []
        
        // 新项目插入到位置0，需要避免与位置1和位置2的项目颜色相似
        if projects.count >= 1 {
            avoidingHues.append(projects[0].hue)
        }
        if projects.count >= 2 {
            avoidingHues.append(projects[1].hue)
        }
        
        let newColor = Project.randomLightColor(avoidingHues: avoidingHues)
        let newProject = Project(name: "", progress: 20, colorRGB: newColor)
        projects.insert(newProject, at: 0)
        saveProjects()
        
        editingProjectId = newProject.id
        editingName = newProject.name
    }

    func startEditing(_ project: Project) {
        if editingProjectId != nil {
            finishEditing()
        }
        editingProjectId = project.id
        editingName = project.name
    }

    func updateEditingName(_ name: String) {
        editingName = name
        guard let id = editingProjectId else { return }

        if let index = projects.firstIndex(where: { $0.id == id }) {
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            projects[index].name = trimmedName
            saveProjects()
        }
    }

    func finishEditing() {
        guard let id = editingProjectId else { return }

        if let index = projects.firstIndex(where: { $0.id == id }) {
            let trimmedName = editingName.trimmingCharacters(in: .whitespaces)
            projects[index].name = trimmedName
            saveProjects()
        }

        editingProjectId = nil
        editingName = ""
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }
    
    func moveProject(from source: IndexSet, to destination: Int) {
        projects.move(fromOffsets: source, toOffset: destination)
        saveProjects()
    }

    func updateProgress(_ project: Project, progress: Double) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].progress = progress
            saveProjects()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if editingProjectId != nil {
                            finishEditing()
                        }
                    }

                VStack(spacing: 0) {
                    List {
                        ForEach(projects) { project in
                            ProjectRow(
                                project: project,
                                isEditing: editingProjectId == project.id,
                                editingName: editingProjectId == project.id ? $editingName : .constant(project.name),
                                onStartEdit: { startEditing(project) },
                                onNameChange: { updateEditingName($0) },
                                onFinishEdit: { finishEditing() },
                                onProgressChange: { updateProgress(project, progress: $0) },
                                onLongPress: { isEditingMode = true },
                                isDragging: isEditingMode
                            )
                            .listRowBackground(backgroundColor)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteProject(project)
                                } label: {
                                    Label(NSLocalizedString("delete", comment: "Delete"), systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveProject)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .onTapGesture {
                        if editingProjectId != nil {
                            finishEditing()
                        }
                        if isEditingMode {
                            isEditingMode = false
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: projects)
                }

            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(appTitle)
                        .foregroundColor(textColor)
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSetTheme = true
                            isDarkMode.toggle()
                        }
                    }) {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                            .foregroundColor(textColor)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        addProject()
                        isEditingMode = false
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(textColor)
                    }
                }
            }
        }
        .onAppear {
            if !isLoaded {
                loadProjects()
                isLoaded = true
            }
        }
    }
}

struct ProjectRow: View {
    let project: Project
    let isEditing: Bool
    @Binding var editingName: String
    let onStartEdit: () -> Void
    let onNameChange: (String) -> Void
    let onFinishEdit: () -> Void
    let onProgressChange: (Double) -> Void
    let onLongPress: () -> Void
    let isDragging: Bool

    @State private var localProgress: Double = 0
    @State private var isProgressDragging = false
    @FocusState private var isNameFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(project: Project, isEditing: Bool, editingName: Binding<String>, onStartEdit: @escaping () -> Void, onNameChange: @escaping (String) -> Void, onFinishEdit: @escaping () -> Void, onProgressChange: @escaping (Double) -> Void, onLongPress: @escaping () -> Void = {}, isDragging: Bool = false) {
        self.project = project
        self.isEditing = isEditing
        self._editingName = editingName
        self.onStartEdit = onStartEdit
        self.onNameChange = onNameChange
        self.onFinishEdit = onFinishEdit
        self.onProgressChange = onProgressChange
        self.onLongPress = onLongPress
        self.isDragging = isDragging
        self._localProgress = State(initialValue: project.progress)
    }

    var progressColor: Color {
        project.color
    }

    var nameText: String {
        isEditing ? editingName : project.displayName
    }

    var projectTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var projectSecondaryColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }

    var projectTrackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.04)
    }

    var projectKnobColor: Color {
        colorScheme == .dark ? .white : .white
    }

    var projectShadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(nameText)
                        .foregroundColor(projectTextColor)
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isDragging {
                                onStartEdit()
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.3) {
                            onLongPress()
                        }
                        .overlay(
                            Group {
                                if isEditing {
                                    TextField("", text: $editingName)
                                        .textFieldStyle(.plain)
                                        .foregroundColor(projectTextColor)
                                        .font(.system(size: 18, weight: .bold))
                                        .frame(minHeight: 24)
                                        .focused($isNameFocused)
                                        .onAppear {
                                            isNameFocused = true
                                        }
                                        .onChange(of: editingName) { _, newValue in
                                            onNameChange(newValue)
                                        }
                                        .onSubmit {
                                            onFinishEdit()
                                        }
                                }
                            }
                        )

                if isDragging {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(projectSecondaryColor)
                        .font(.system(size: 18))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(projectTrackColor)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressColor)
                        .frame(width: max(0, geometry.size.width * (localProgress / 100)), height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: localProgress)

                    Circle()
                        .fill(projectKnobColor)
                        .frame(width: 24, height: 24)
                        .shadow(radius: 3)
                        .offset(x: max(0, geometry.size.width * (localProgress / 100) - 12))
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: localProgress)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isProgressDragging = true
                                    if isEditing {
                                        onFinishEdit()
                                    }
                                    let x = value.location.x
                                    let width = geometry.size.width
                                    let newProgress = (x / width) * 100
                                    localProgress = max(0, min(100, newProgress))
                                }
                                .onEnded { _ in
                                    isProgressDragging = false
                                }
                        )
                }
            }
            .frame(height: 26)
            .padding(.horizontal, 20)

            HStack {
                Spacer()
                Text(String(format: "%.0f%%", localProgress))
                    .foregroundColor(projectSecondaryColor)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .scaleEffect(isDragging ? 1.02 : 1)
        .shadow(color: isDragging ? projectShadowColor : .clear, radius: isDragging ? 10 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .onTapGesture {
            if isEditing {
                onFinishEdit()
            }
        }
        .onChange(of: localProgress) { _, newValue in
            onProgressChange(newValue)
        }
        .onChange(of: project.progress) { _, newValue in
            if !isProgressDragging {
                localProgress = newValue
            }
        }
        .onAppear {
            localProgress = project.progress
        }
    }
}

#Preview("ContentView") {
    ContentView()
}

#Preview("AppIcon") {
    ZStack {
        Color.black
        
        Circle()
            .stroke(Color.white.opacity(0.6), lineWidth: 8)
            .padding(20)
        
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.5, blue: 0.5),
                        Color(red: 1.0, green: 0.6, blue: 0.2),
                        Color(red: 0.9, green: 0.6, blue: 0.9),
                        Color(red: 0.2, green: 0.6, blue: 1.0),
                        Color(red: 0.3, green: 0.9, blue: 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 16, lineCap: .round)
            )
            .padding(28)
            .rotationEffect(.degrees(-90))
    }
    .frame(width: 1024, height: 1024)
}
