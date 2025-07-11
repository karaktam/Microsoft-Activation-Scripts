//
//  StitchRootView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/15/23.
//

import SwiftUI
import StitchSchemaKit

extension CGFloat {
#if DEV_DEBUG
    static let STITCH_APP_WINDOW_MINIMUM_WIDTH: CGFloat = 400
    static let STITCH_APP_WINDOW_MINIMUM_HEIGHT: CGFloat = 200
#else
    static let STITCH_APP_WINDOW_MINIMUM_WIDTH: CGFloat = 800
    static let STITCH_APP_WINDOW_MINIMUM_HEIGHT: CGFloat = 600
#endif
}

struct StitchRootView: View {
    @Environment(StitchFileManager.self) var fileManager
    
    @Bindable var store: StitchStore
    
    @MainActor
    var alertState: ProjectAlertState {
        self.store.alertState
    }
    
    var isShowingDrawer: Bool {
        self.store.isShowingDrawer
    }
    
    // "Is NavigationSplitView's sidebar open or not?"
    // Handled manually by user; but synced with StitchDocumentViewModel.leftSide
    @State var columnVisibility: NavigationSplitViewVisibility = .detailOnly
            
    var showMenu: Bool {
         guard let document = store.currentDocument else {
             return false
         }

         return document.insertNodeMenuState.show || document.isLoadingAI
    }
    
    @ViewBuilder
    var viewByPlatform: some View {
#if targetEnvironment(macCatalyst)
                splitView
#else
                StitchNavStack(store: store)
#endif
    }
    
    var body: some View {
        ZStack {
            if Stitch.isPhoneDevice {
                iPhoneBody
            } else {
                viewByPlatform
                    .overlay(alignment: .center) {
                        if let document = store.currentDocument {
                            
                            if showMenu {
                                InsertNodeMenuWithModalBackground(document: document)
                            }
                            
                            switch document.llmRecording.modal {
                                
                            case .submitExistingGraphAsTrainingExample:
                                SubmitExistingGraphAsTrainingExampleModalView(
                                    promptFromPreviousExistingGraphSubmittedAsTrainingData: document.llmRecording.promptFromPreviousExistingGraphSubmittedAsTrainingData,
                                    ratingFromPreviousExistingGraphSubmittedAsTrainingData: document.llmRecording.ratingFromPreviousExistingGraphSubmittedAsTrainingData
                                )
                                
                            case .aiNodePromptEntry:
                                AINodePromptEntryModalView(document: document)
             
//                                EmptyView()
                                
                                
                            case .editBeforeSubmit, .none, .ratingToast:
                                EmptyView()  // handled elsewhere
                            }
                        } // if let document
                    } // .overlay
            }
        }    
        .modifier(StitchRootModifier())
        .onAppear {
            // TODO: move this to the start of StitchStore instead?
            //            dispatch(ImportDefaultComponents())
            
            hideTitleAndSetMinimumWindowSize()
        }
        .onChange(of: self.columnVisibility, initial: true) { oldValue, newValue in
            let fn = { (open: Bool) in dispatch(LeftSidebarSet(open: open)) }
            
            switch newValue {
            case .all:
                fn(true)
            case .detailOnly:
                fn(false)
            case .doubleColumn:
                fn(true)
            // When and how can this case happen?
            case .automatic:
                fn(false)
            default:
                fn(false)
            }
        }
        .onChange(of: self.store.currentDocument?.leftSidebarOpen ?? false) { oldValue, newValue in
//            dispatch(LeftSidebarSet(open: true))
            if newValue {
                self.columnVisibility = .doubleColumn
            } else {
                self.columnVisibility = .detailOnly
            }       
        }
    }
    
    // TODO: why doesn't `mySwiftUIScene.windowStyle(.hidden)` compile even when behind `#if targetEnvironment(macCatalyst)` flag ?
    @MainActor
    func hideTitleAndSetMinimumWindowSize() {
#if targetEnvironment(macCatalyst)
        if let windowScene = (UIApplication.shared.connectedScenes.first as? UIWindowScene) {
            windowScene.titlebar?.titleVisibility = .hidden
            windowScene.titlebar?.toolbarStyle = .unified
            windowScene.sizeRestrictions?.minimumSize = .init(
                width: .STITCH_APP_WINDOW_MINIMUM_WIDTH,
                height: .STITCH_APP_WINDOW_MINIMUM_HEIGHT)
        } else {
            fatalErrorIfDebug("StitchRootView: unable to retrieve UIWindowScene")
        }
#endif
    }
    
    var iPhoneBody: some View {
        
        // `NavigationSplitView` does not respect `NavigationSplitViewVisibility.detailOnly` on iPhone;
        // but since we show neither components- nor layers-sidebars on iPhone,
        // we don't need to use `NavigationSplitView`.
        StitchNavStack(store: store)
    }
    
    @MainActor
    var splitView: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            sidebar: {
                topLevelSidebar
                
                // Needed on Catalyst to prevent sidebar button from sliding into traffic light buttons
//#if targetEnvironment(macCatalyst)
//                    .toolbar(.hidden)
//#endif
            },
            // Apple's 'detail view' = the view to the right of the sidebar
            detail: {
                // The NavigationStack which switches between
                // Projects Home View <-> some Loaded Project;
                // gives us proper back button etc.
                StitchNavStack(store: store)
//                    .coordinateSpace(name: Self.STITCH_ROOT_VIEW_COORDINATE_SPACE)
            })
        .coordinateSpace(name: Self.STITCH_ROOT_VIEW_COORDINATE_SPACE)
        
        
        // NOT NEEDED ANYMORE ?
        
        // On iPad's graph view, we use a custom top bar, and so do not have the native bar's sidebar-icon for opening or closing sidebar;
        // instead we listen to redux state.
#if !targetEnvironment(macCatalyst)
        .onChange(of: isShowingDrawer) { newValue in
            columnVisibility = newValue ? .all : .detailOnly
        }
        .onChange(of: self.store.currentDocument.isDefined) { isProjectOpened in
            // If we close graph while sidebar is open,
            // we need to also close sidebar
            // since otherwise the native nav bar's sidebar icon can get lost.
            // (Finicky.)
            if !isProjectOpened {
                columnVisibility = .detailOnly
            }
        }
#endif
        
        // Update Redux when drawer state changes
        .onChange(of: self.columnVisibility) { _, newColumnVisibility in
            switch newColumnVisibility {
            case .all, .doubleColumn:
                dispatch(ShowDrawer())
            case .automatic, .detailOnly:
                dispatch(HideDrawer())
            default:
                dispatch(HideDrawer())
            }
        }
    }
    
    static let STITCH_ROOT_VIEW_COORDINATE_SPACE = "STITCH_ROOT_VIEW_COORDINATE_SPACE"
    
    // TODO: remove on Catalyst
    @Namespace var topButtonNamespace
    
    @ViewBuilder
    var topLevelSidebar: some View {
        StitchSidebarView(syncStatus: fileManager.syncStatus)
    }
}
