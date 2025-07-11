//
//  ContentView.swift
//  prototype
//
//  Created by cjc on 11/1/20.
//

import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 CONTENT VIEW
 ---------------------------------------------------------------- */

struct ContentView: View, KeyboardReadable {
    @State private var menuHeight: CGFloat = INSERT_NODE_MENU_MAX_HEIGHT
    
    // Controlled by a GeometryReader that respects keyboard safe-area,
    // so that menuOrigin respects actual height of screen
    // (which is smaller when full-screen keyboard is on-screen).
    @State private var screenSize: CGSize = .zero
    
    @Namespace private var graphNamespace
    @StateObject private var showFullScreen = AnimatableBool(false)
    @State private var showFullScreenAnimateCompleted = true
    
    // Controls the animation of newly created node from the insert node menu
    @State private var previewingNodeChoice: InsertNodeMenuOption?

    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel

    let alertState: ProjectAlertState
    let routerNamespace: Namespace.ID
    
    var previewWindowSizing: PreviewWindowSizing {
        self.document.previewWindowSizingObserver
    }

    /// Shows menu wrapper view while node animation takes place
    var showMenu: Bool {
        document.insertNodeMenuState.show
    }

    var nodeAndMenu: some View {
        ZStack {
            
            // Best place to listen for TAB key for flyout
            UIKitWrapper(ignoresKeyCommands: true,
                         isOnlyForTextFieldHelp: true,
                         inputTextFieldFocused: document.reduxFocusedField?.inputTextFieldWithNumberIsFocused(document.graph) ?? false,
                         name: .mainGraph) {
                contentView // the graph
            }
        }
    }

    var body: some View {
        ZStack {
            
            // probably the best location for listening to how iPad's on-screen keyboard reduces available height for node menu ?
            
            
            // Must respect keyboard safe-area
            ProjectWindowSizeReader(previewWindowSizing: previewWindowSizing,
                                    previewWindowSize: document.previewWindowSize,
                                    isFullScreen: document.isFullScreenMode,
                                    showFullScreenAnimateCompleted: $showFullScreenAnimateCompleted,
                                    showFullScreenObserver: showFullScreen,
                                    menuHeight: menuHeight)

            // Must IGNORE keyboard safe-area
            nodeAndMenu
#if !targetEnvironment(macCatalyst)
                .ignoresSafeArea(edges: showFullScreen.isTrue ? [.all] : [.bottom])
                .ignoresSafeArea([.keyboard])
#endif
        }
        
        // TODO: remove these? just access from document in the relevant view?
        // TODO: not actually used/accessed ?
       .environment(\.viewframe, document.frame)
    }

    @ViewBuilder
    var contentView: some View {
        ZStack {
            
            // ALWAYS show full-screen preview on iPhone.
            // Also, if in full-screen preview mode on Catalyst or iPad, place the fullscreen preview on top.
            if showFullScreen.isTrue || StitchDocumentViewModel.isPhoneDevice {
                fullScreenPreviewView
                    .modifier(FullScreenPreviewViewModifier(document: document))
            } // if showFullScreen.isTrue
            
            // NEVER show graph-view on iPhone
            if !StitchDocumentViewModel.isPhoneDevice {
                // Check if we're on iPhone, otherwise the project view will start to render on
                // phone before showFullScreen is set
                ProjectNavigationView(store: store,
                                      document: document,
                                      graph: document.visibleGraph,
                                      isFullScreen: showFullScreen.isTrue,
                                      routerNamespace: routerNamespace,
                                      graphNamespace: graphNamespace)
                .zIndex(showFullScreen.isTrue ? -99 : 0)
                .overlay {
                    catalystProjectTitleEditView
                }
                
                // NOTE: APPARENTLY NOT NEEDED ANYMORE?
//                // Note: we want the floating preview window to 'ignore safe areas' (e.g. the keyboard rising up should not affect preview window's size or position):
//                // we must apply the `.ignoresSafeArea` modifier to the ProjectNavigationView, rather than .overlay's contents
//                #if !targetEnvironment(macCatalyst)
//                                .ignoresSafeArea(edges: showFullScreen.isTrue ? [.all] : [.bottom])
//                                .ignoresSafeArea([.keyboard])
//                #endif
            }
        } // ZStack
        
        .stitchSheet(isPresented: alertState.showProjectSettings,
                     titleLabel: "Settings",
                     hideAction: store.hideProjectSettingsSheet) {
            ProjectSettingsView(previewWindowSize: document.previewWindowSize,
                                previewSizeDevice: document.previewSizeDevice,
                                previewWindowBackgroundColor: document.previewWindowBackgroundColor,
                                graph: document.graph,
                                document: document) }
        .modifier(FileImportView(fileImportState: alertState.fileImportModalState))
        .modifier(AnimateCompletionHandler(percentage: showFullScreen.value) {
            // only set this state to true when we're animating into full screen mode
            DispatchQueue.main.async {
                self.showFullScreenAnimateCompleted = true
            }
        })
        .alert("Stitch AI Training Upload",
               isPresented: $document.llmRecording.willDisplayTrainingPrompt,
               actions: {
            TextField("Prompt", text: $document.llmRecording.promptForTrainingDataOrCompletedRequest)
            
            StitchButton("Confirm Before Uploading") {
                // Populate actions data for providing sidebar UX--to be removed
                document.llmRecording.actions = AIGraphDescriptionRequest
                    .deriveStepActionsFromSelectedState(document: document)
                
                // Open the Edit-before-submit modal
                document.showEditBeforeSubmitModal()
            }
            StitchButton("Cancel", role: .cancel) {
                document.llmRecording.promptForTrainingDataOrCompletedRequest = ""
            }
        }, message: {
            Text("Describe your selected subgraph.")
        })
    }
    
    private var fullScreenPreviewView: some View {
        FullScreenPreviewViewWrapper(
            document: document,
            previewWindowSizing: self.previewWindowSizing,
            showFullScreenPreviewSheet: alertState.showFullScreenPreviewSheet,
            graphNamespace: graphNamespace,
            routerNamespace: routerNamespace,
            animationCompleted: showFullScreenAnimateCompleted)
    }
    
    @ViewBuilder
    var catalystProjectTitleEditView: some View {
#if targetEnvironment(macCatalyst)
        if document.showCatalystProjectTitleModal {
//            VStack(alignment: .leading) {
//                StitchTextView(string: "Edit Project Title")
                CatalystProjectTitleModalView(graph: document.visibleGraph,
                                              document: document)
//            }
            .padding()
            .frame(width: 360, alignment: .leading)
            .background(
                Color(uiColor: .systemGray5)
                // NOTE: strangely we need `[.all, .keyboard]` on BOTH the background color AND the StitchHostingControllerView
                    .ignoresSafeArea([.all, .keyboard])
                    .cornerRadius(4)
            )
            .position(
                x: 180 // half width of edit view itself, so its left-edge sits at screen's left-edge
                + 16 // padding
                // + 330 // traffic lifts, sidebar button
                + 158
                + (document.leftSidebarOpen ? (-SIDEBAR_WIDTH/2 + 38) : 0)
                
//                , y: 52)
                , y: 36)
                
        } // if document
#endif
    }
}
