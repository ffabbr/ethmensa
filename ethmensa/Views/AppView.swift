//
//  Copyright © 2026 Alexandre Reol
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>.
//

import SwiftUI
import URLImage

#if canImport(WhatsNewKit)
import WhatsNewKit
#endif

extension EnvironmentValues {
    @Entry var imageViewerNamespace: Namespace.ID?
}

struct AppView: View {

    @Environment(\.openURL) private var openURL

    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var mensaDataManager: MensaDataManager
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var settingsManager: SettingsManager

    @Namespace private var imageViewerNamespace
    @State private var imageViewerOffset: CGSize = .zero
    @State private var showOnboarding = !SettingsManager.shared.completedFirstLaunch

    var body: some View {
        NavigationSplitView {
            MainView()
        } detail: {
            DetailView()
        }
        .environmentObject(navigationManager)
        .environmentObject(mensaDataManager)
        .environmentObject(settingsManager)
        .environment(\.imageViewerNamespace, imageViewerNamespace)
        .fullScreenCover(isPresented: $networkManager.isOffline) {
            ModalViewUI(viewModel: .noInternet)
        }
        .versionIncompatibleIfNeeded(
            host: API.shared.host,
            tintColor: .accent,
            appIcon: .appIconRoundedForUserVersion
        ) {
            openURL(String.appStoreURLString.toURL()!)
        } detailButtonAction: {
            openURL(String.automaticUpdatesURLString.toURL()!)
        }
#if !APPCLIP && !os(visionOS)
        .onboardingFullScreenCoverIfNecessary(
            showOnboarding: $showOnboarding
        ) {
            settingsManager.completedFirstLaunch = true
        }
#endif
#if APPCLIP
        .skOverlay()
#elseif canImport(WhatsNewKit)
        .whatsNewSheet()
#endif
        .openURL(
            universalLinkAlertShown: $navigationManager.universalLinkAlertShown,
            universalLinkMensaId: $navigationManager.universalLinkMensaId
        )
        .sheet(item: $navigationManager.sheet) { type in
            AppViewSheets(type: type)
                .environmentObject(navigationManager)
                .environmentObject(settingsManager)
        }
        // MARK: - Sheet-based image viewer (commented out)
//        .sheet(isPresented: $navigationManager.imagePopoverShown) {
//            NavigationStack {
//                Group {
//                    if let url = navigationManager.imagePopoverURL {
//                        URLImage(url: url) {
//                            ProgressView()
//                        } inProgress: { _ in
//                            ProgressView()
//                        } failure: { _, _ in
//                            Image(.appIconRoundedForUserVersion)
//                                .resizable()
//                                .scaledToFit()
//                        } content: { image in
//                            image
//                                .resizable()
//                                .scaledToFit()
//                        }
//                    }
//                }
//                .toolbar {
//                    ToolbarItem(placement: .topBarTrailing) {
//                        Button("CLOSE", systemImage: "xmark.circle.fill") {
//                            navigationManager.imagePopoverShown = false
//                        }
//                        .labelStyle(.iconOnly)
//                    }
//                }
//                .background(.black)
//                .toolbarBackground(.hidden, for: .navigationBar)
//            }
//        }
        // MARK: - matchedGeometryEffect image viewer
        .overlay {
            if navigationManager.imagePopoverShown, let url = navigationManager.imagePopoverURL {
                Color.black
                    .opacity(
                        navigationManager.imagePopoverActive
                            ? 1.0 - min(1.0, abs(imageViewerOffset.height) / 300.0)
                            : 0
                    )
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismissImageViewer)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("CLOSE")

                URLImage(url: url) {
                    ProgressView()
                } inProgress: { _ in
                    ProgressView()
                } failure: { _, _ in
                    Image(.appIconRoundedForUserVersion)
                        .resizable()
                        .scaledToFit()
                } content: { image in
                    image
                        .resizable()
                        .scaledToFit()
                }
                .clipShape(.rect(cornerRadius: navigationManager.imagePopoverActive ? 0 : 10))
                .opacity(navigationManager.imagePopoverActive ? 1 : 0)
                .matchedGeometryEffect(
                    id: url.absoluteString,
                    in: imageViewerNamespace,
                    isSource: navigationManager.imagePopoverActive
                )
                .offset(imageViewerOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            imageViewerOffset = value.translation
                        }
                        .onEnded { value in
                            if abs(value.translation.height) > 100 {
                                dismissImageViewer()
                            } else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    imageViewerOffset = .zero
                                }
                            }
                        }
                )
            }
        }
    }

    private func dismissImageViewer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            navigationManager.imagePopoverActive = false
            imageViewerOffset = .zero
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            navigationManager.imagePopoverShown = false
        }
    }
}

#Preview {
    AppView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(MensaDataManager.shared)
        .environmentObject(SettingsManager.shared)
}
