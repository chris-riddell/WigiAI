//
//  MessageListView.swift
//  WigiAI
//
//  Message list display with scrolling and animations
//

import SwiftUI

struct MessageListView: View {
    let messages: [Message]
    let isThinking: Bool
    let isStreaming: Bool
    let streamingResponse: String
    let characterId: UUID
    let characterName: String
    let scrollToBottomTrigger: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty && !isStreaming && !isThinking {
                        // Empty state
                        VStack(spacing: 16) {
                            Spacer()

                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.5))

                            Text("Start a conversation")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Say hello or ask a question to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(groupMessages(messages).enumerated()), id: \.element.id) { index, group in
                                MessageGroup(
                                    group: group,
                                    isLastGroup: index == groupMessages(messages).count - 1,
                                    containerWidth: geometry.size.width
                                )
                            }

                            // Thinking indicator
                            if isThinking {
                                TypingIndicator()
                                    .id("thinking")
                                    .transition(.opacity.combined(with: .scale))
                            }

                            // Streaming response
                            if isStreaming && !streamingResponse.isEmpty {
                                MessageBubble(
                                    message: Message(
                                        role: "assistant",
                                        content: streamingResponse
                                    ),
                                    isFirstInGroup: true,
                                    isLastInGroup: true,
                                    showTimestamp: false,
                                    containerWidth: geometry.size.width
                                )
                                .id("streaming")
                            }

                            // Invisible bottom marker for reliable scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding()
                    }
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollChatToBottom"))) { notification in
                    // Check if this notification is for this character
                    if let notificationCharacterId = notification.object as? UUID,
                       notificationCharacterId == characterId {
                        LoggerService.ui.debug("📜 Received scroll notification for \(characterName)")
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: messages.count) {
                    // Scroll to bottom marker when history changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    // Extra scroll with longer delay to ensure full render
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: streamingResponse) {
                    // Immediate scroll during streaming
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isThinking) {
                    // Scroll when thinking starts
                    if isThinking {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo("thinking", anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: scrollToBottomTrigger) {
                    // Manual scroll trigger (when user sends message)
                    // Multiple attempts with increasing delays to ensure content is rendered
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // Helper to scroll to bottom with multiple attempts
    private func scrollToBottom(proxy: ScrollViewProxy) {
        // Immediate attempt
        DispatchQueue.main.async {
            proxy.scrollTo("bottom", anchor: .bottom)
        }

        // Short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }

        // Medium delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }

        // Longer delay with animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Message Grouping

    private func groupMessages(_ messages: [Message]) -> [MessageGroupData] {
        var groups: [MessageGroupData] = []
        var currentGroup: [Message] = []
        var currentRole: String? = nil

        for message in messages {
            if message.role == currentRole {
                // Same sender, add to current group
                currentGroup.append(message)
            } else {
                // Different sender, save current group and start new one
                if !currentGroup.isEmpty {
                    groups.append(MessageGroupData(messages: currentGroup))
                }
                currentGroup = [message]
                currentRole = message.role
            }
        }

        // Don't forget the last group
        if !currentGroup.isEmpty {
            groups.append(MessageGroupData(messages: currentGroup))
        }

        return groups
    }
}

// MARK: - Message Group Data

struct MessageGroupData: Identifiable {
    let id = UUID()
    let messages: [Message]

    var role: String {
        messages.first?.role ?? "user"
    }

    var timestamp: Date {
        messages.last?.timestamp ?? Date()
    }
}

// MARK: - Message Group

struct MessageGroup: View {
    let group: MessageGroupData
    let isLastGroup: Bool
    var containerWidth: CGFloat = 400

    var body: some View {
        VStack(alignment: group.role == "user" ? .trailing : .leading, spacing: 2) {
            ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                MessageBubble(
                    message: message,
                    isFirstInGroup: index == 0,
                    isLastInGroup: index == group.messages.count - 1,
                    showTimestamp: index == group.messages.count - 1,
                    containerWidth: containerWidth
                )
            }

            // Timestamp for the group
            if isLastGroup {
                Text(group.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
            }
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Message Bubble

// Custom corner specification for macOS (UIRectCorner doesn't exist on macOS)
struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct MessageBubble: View {
    let message: Message
    var isFirstInGroup: Bool = true
    var isLastInGroup: Bool = true
    var showTimestamp: Bool = true
    var containerWidth: CGFloat = 400
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            if message.role == "user" {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                // Message bubble
                Text(message.content)
                    .fixedSize(horizontal: false, vertical: true)  // Allow text to wrap
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if message.role == "user" {
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                Color.clear
                                    .background(.regularMaterial)
                            }
                        }
                    )
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .clipShape(
                        BubbleShape(
                            corners: getBubbleCorners(),
                            hasTail: false
                        )
                    )
                    .shadow(
                        color: .black.opacity(isHovering ? 0.12 : 0.06),
                        radius: isHovering ? 8 : 4,
                        x: 0,
                        y: 2
                    )
                    .contextMenu {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        }) {
                            Label("Copy Message", systemImage: "doc.on.doc")
                        }
                    }
            }
            .frame(maxWidth: max(200, containerWidth * 0.75), alignment: message.role == "user" ? .trailing : .leading)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }

            if message.role == "assistant" {
                Spacer(minLength: 50)
            }
        }
    }

    private func getBubbleCorners() -> RectCorner {
        var corners: RectCorner = .allCorners

        if message.role == "user" {
            if !isFirstInGroup {
                corners.remove(.topRight)
            }
            if !isLastInGroup {
                corners.remove(.bottomRight)
            }
        } else {
            if !isFirstInGroup {
                corners.remove(.topLeft)
            }
            if !isLastInGroup {
                corners.remove(.bottomLeft)
            }
        }

        return corners
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let corners: RectCorner
    let hasTail: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = hasTail ? 6 : 0

        var path = Path()

        // Adjust rect for tail
        let adjustedRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width - tailSize,
            height: rect.height
        )

        path.move(to: CGPoint(x: adjustedRect.minX + radius, y: adjustedRect.minY))

        // Top right
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: adjustedRect.maxX - radius, y: adjustedRect.minY))
            path.addQuadCurve(
                to: CGPoint(x: adjustedRect.maxX, y: adjustedRect.minY + radius),
                control: CGPoint(x: adjustedRect.maxX, y: adjustedRect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: adjustedRect.maxX, y: adjustedRect.minY))
        }

        // Bottom right
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: adjustedRect.maxX, y: adjustedRect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: adjustedRect.maxX - radius, y: adjustedRect.maxY),
                control: CGPoint(x: adjustedRect.maxX, y: adjustedRect.maxY)
            )
        } else {
            path.addLine(to: CGPoint(x: adjustedRect.maxX, y: adjustedRect.maxY))
        }

        // Bottom left
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: adjustedRect.minX + radius, y: adjustedRect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: adjustedRect.minX, y: adjustedRect.maxY - radius),
                control: CGPoint(x: adjustedRect.minX, y: adjustedRect.maxY)
            )
        } else {
            path.addLine(to: CGPoint(x: adjustedRect.minX, y: adjustedRect.maxY))
        }

        // Top left
        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: adjustedRect.minX, y: adjustedRect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: adjustedRect.minX + radius, y: adjustedRect.minY),
                control: CGPoint(x: adjustedRect.minX, y: adjustedRect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: adjustedRect.minX, y: adjustedRect.minY))
        }

        path.closeSubpath()

        return path
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animatingDot1 = false
    @State private var animatingDot2 = false
    @State private var animatingDot3 = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(getScale(for: index))
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: getAnimatingState(for: index)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .onAppear {
            animatingDot1 = true
            animatingDot2 = true
            animatingDot3 = true
        }
    }

    private func getScale(for index: Int) -> CGFloat {
        switch index {
        case 0: return animatingDot1 ? 1.3 : 1.0
        case 1: return animatingDot2 ? 1.3 : 1.0
        case 2: return animatingDot3 ? 1.3 : 1.0
        default: return 1.0
        }
    }

    private func getAnimatingState(for index: Int) -> Bool {
        switch index {
        case 0: return animatingDot1
        case 1: return animatingDot2
        case 2: return animatingDot3
        default: return false
        }
    }
}
