//
//  Router.swift
//  SnazzyRouter
//
//  Created by Dubon Ya'ar on 08/08/2025.
//

import SwiftUI

public protocol Routable: Hashable, Identifiable {
    associatedtype DestinationView: View

    @MainActor
    @ViewBuilder
    var view: DestinationView { get }
}

public extension Routable {
    var id: String {
        "\(type(of: self))\(String(describing: self))"
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct RouterModalItem<D: Routable>: Identifiable, Equatable {
    public let destination: D
    public let dismiss: (() -> Void)?

    public init(destination: D, dismiss: (() -> Void)? = nil) {
        self.destination = destination
        self.dismiss = dismiss
    }

    public var id: String {
        destination.id
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Dialog Action

public struct DialogAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let role: ButtonRole?
    public let action: () -> Void

    public init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }
}

// MARK: - Confirmation Dialog Configuration

public struct ConfirmationDialogConfiguration {
    public let title: String
    public let message: String?
    public let actions: [DialogAction]

    public init(title: String, message: String? = nil, actions: [DialogAction]) {
        self.title = title
        self.message = message
        self.actions = actions
    }
}

@Observable
public class RouterState<D: Routable> {
    public init() {}

    public var path: [D] = []
    public var fullScreenCover: RouterModalItem<D>?
    public var popover: RouterModalItem<D>?
    public var sheet: RouterModalItem<D>?

    // Alert and dialog support
    public var alert: Alert?
    public var confirmationDialog: ConfirmationDialogConfiguration?

    // MARK: - Navigation Methods

    public func push(_ destination: D) {
        path.append(destination)
    }

    public func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    public func popToRoot() {
        path.removeAll()
    }

    // MARK: - Alert Methods

    public func showAlert(_ alert: Alert) {
        self.alert = alert
    }

    public func showConfirmationDialog(title: String, message: String? = nil, actions: [DialogAction]) {
        confirmationDialog = ConfirmationDialogConfiguration(title: title, message: message, actions: actions)
    }
}

public struct RouterView<D: Routable, Content: View>: View {
    @State private var provider: RouterState<D>
    private let content: (RouterState<D>) -> Content

    public init(provider: RouterState<D>, @ViewBuilder content: @escaping (RouterState<D>) -> Content) {
        self.provider = provider
        self.content = content
    }

    public init(@ViewBuilder content: @escaping (RouterState<D>) -> Content) where D: Routable {
        self.init(provider: RouterState<D>(), content: content)
    }

    public var body: some View {
        NavigationStack(path: $provider.path) {
            content(provider)
                .navigationDestination(for: D.self) { route in
                    route.view
                }
                .sheet(item: $provider.sheet) { item in
                    item.destination.view
                        .onDisappear {
                            item.dismiss?()
                        }
                }
                .popover(item: $provider.popover) { item in
                    item.destination.view
                        .onDisappear {
                            item.dismiss?()
                        }
                }
                .fullScreenCover(item: $provider.fullScreenCover) { item in
                    item.destination.view
                        .onDisappear {
                            item.dismiss?()
                        }
                }
        }
        .alert(isPresented: Binding<Bool>(
            get: { provider.alert != nil },
            set: { _ in provider.alert = nil }
        )) {
            provider.alert ?? Alert(title: Text(""))
        }
        .confirmationDialog(
            provider.confirmationDialog?.title ?? "",
            isPresented: Binding<Bool>(
                get: { provider.confirmationDialog != nil },
                set: { _ in provider.confirmationDialog = nil }
            ),
            titleVisibility: .visible
        ) {
            if let dialog = provider.confirmationDialog {
                ForEach(dialog.actions) { action in
                    Button(action.title, role: action.role) {
                        action.action()
                        provider.confirmationDialog = nil
                    }
                }
            }
        } message: {
            if let message = provider.confirmationDialog?.message {
                Text(message)
            }
        }
        .environment(provider)
    }
}

// MARK: - Router View for Clean Syntax

/// A view that eliminates the need for underscore in RouterView type parameters
public struct Router<D: Routable, Content: View>: View {
    private let provider: RouterState<D>
    private let content: (RouterState<D>) -> Content

    public init(_ type: D.Type, provider: RouterState<D>? = nil, @ViewBuilder content: @escaping (RouterState<D>) -> Content) {
        self.provider = provider ?? RouterState<D>()
        self.content = content
    }

    public var body: some View {
        RouterView<D, Content>(provider: provider, content: content)
    }
}

// MARK: - Usage Examples

// Your example converted to use the Router builder (no underscore!)
enum MyDestination: Routable {
    case a

    @MainActor
    @ViewBuilder
    var view: some View {
        Color.red
    }
}

// Example
struct A: View {
    var body: some View {
        Router(MyDestination.self) { _ in
            Color.blue
        }
    }
}

struct SubView: View {
    @Environment(RouterState<MyDestination>.self) var router

    var body: some View {
        Text("Hello, World!")
        Button("Go Root") {
            router.popToRoot()
        }
    }
}
