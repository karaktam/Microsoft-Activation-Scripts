//
//  CopyAndPasteNodesActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/20/23.
//

import Foundation
import StitchSchemaKit
import UIKit

typealias PredicateT<T> = (T) -> Bool
typealias PredicateTK<T, K> = (T, K) -> Bool

// Must be
// "Cut" = cuts both selected nodes AND selected comments

struct SelectedGraphItemsCut: StitchDocumentEvent {

    func handle(state: StitchDocumentViewModel) {
        log("SelectedGraphNodesCut called")
        
        let graph = state.visibleGraph

        // Copy selected graph data to clipboard
        graph.copyToClipboard(selectedNodeIds: graph.selectedPatchAndLayerNodes,
                              groupNodeFocused: state.groupNodeFocused)

        // Delete selected nodes
        graph.selectedCanvasItems.forEach {
            graph.deleteCanvasItem($0, document: state)
        }

        // TODO: APRIL 11: should not be necessary anymore? since causes a persistence change
         graph.updateGraphData(state)
        
        state.encodeProjectInBackground()
        
        
    }
}

extension GraphState {
    @MainActor
    var selectedPatchAndLayerNodes: NodeIdSet {
        self.selectedCanvasItems.compactMap(\.nodeCase).toSet
            .union(self.selectedSidebarLayers)
    }
}

// "Copy" = copy shortcut, which copies BOTH nodes AND comments
// struct SelectedGraphNodesCopied: AppEnvironmentEvent {
struct SelectedGraphItemsCopied: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        log("SelectedGraphNodesCopied called")
        
        let graph = state.visibleGraph
        
        graph.copyToClipboard(selectedNodeIds: graph.selectedPatchAndLayerNodes,
                              groupNodeFocused: state.groupNodeFocused)
    }
}

// "Paste" = paste shortcut, which pastes BOTH nodes AND comments
struct SelectedGraphItemsPasted: StitchDocumentEvent {

    func handle(state: StitchDocumentViewModel) {
        
        let pasteboardUrl = StitchClipboardContent.rootUrl

        do {
            let componentData: Data = try Data(contentsOf: pasteboardUrl.appendingVersionedSchemaPath())
            let newComponent: StitchClipboardContent = try getStitchDecoder().decode(StitchClipboardContent.self, from: componentData)
            let importedFiles = try ComponentEncoder.readAllImportedFiles(rootUrl: pasteboardUrl)

            let graph = state.visibleGraph
            
            graph.insertNewComponent(graphEntity: newComponent.graphEntity,
                                     encoder: graph.documentEncoderDelegate,
                                     copiedFiles: importedFiles,
                                     isCopyPaste: true,
                                     originGraphOutputValuesMap: newComponent.originGraphOutputValuesMap,
                                     document: state)
            state.encodeProjectInBackground()
        } catch {
            log("SelectedGraphItemsPasted error: \(error)")
        }
    }
}
