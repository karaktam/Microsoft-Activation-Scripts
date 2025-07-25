//
//  PatchOrLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/25.
//

import Foundation

enum PatchOrLayer: Equatable, Codable {
    case patch(Patch), layer(Layer)
}

// Patch and Layer nodes are very different from Groups and Components; in some contexts it is impossible
enum PatchOrLayerNode {
    case patch(node: NodeViewModel, patch: PatchNodeViewModel)
    case layer(node: NodeViewModel, layer: LayerNodeViewModel)
    
    @MainActor
    var patchOrLayer: PatchOrLayer {
        switch self {
        case .patch(_, let patch):
            return .patch(patch.patch)
        case .layer(_, let layer):
            return .layer(layer.layer)
        }
    }
    
    @MainActor
    var node: NodeViewModel {
        switch self {
        case .patch(let node, _):
            return node
        case .layer(let node, _):
            return node
        }
    }
    
    @MainActor
    var patchNode: PatchNodeViewModel? {
        switch self {
        case .patch(_, let patch):
            return patch
        case .layer:
            return nil
        }
    }
    
    @MainActor
    var layerNode: LayerNodeViewModel? {
        switch self {
        case .patch:
            return nil
        case .layer(_, let layer):
            return layer
        }
    }
}

extension PatchOrLayerNode {
    @MainActor
    init?(_ node: NodeViewModel) {
        switch node.nodeType {
        case .layer(let layerNode):
            self = .layer(node: node, layer: layerNode)
        case .patch(let patchNode):
            self = .patch(node: node, patch: patchNode)
        default:
            fatalErrorIfDebug("Called incorrectly; not applicable to groups or components")
            return nil
        }
    }
}

// i.e. NodeKind, excluding Group Nodes and Components
extension PatchOrLayer {
    var asNodeKind: NodeKind {
        switch self {
        case .patch(let patch):
            return .patch(patch)
        case .layer(let layer):
            return .layer(layer)
        }
    }

    static func from(nodeKind: NodeKind) -> Self? {
        switch nodeKind {
        case .patch(let x):
            return .patch(x)
        case .layer(let x):
            return .layer(x)
        case .group:
            // fatalErrorIfDebug()
            return nil
        }
    }
    
    var patch: Patch? {
        switch self {
        case .patch(let patch):
            return patch
        case .layer:
            return nil
        }
    }
    
    var layer: Layer? {
        switch self {
        case .patch:
            return nil
        case .layer(let layer):
            return layer
        }
    }
}

extension Patch {
    @MainActor
    var patchOrLayer: PatchOrLayer {
        .patch(self)
    }
}

extension Layer {
    @MainActor
    var patchOrLayer: PatchOrLayer {
        .layer(self)
    }
}


extension PatchNodeViewModel {
    @MainActor
    var patchOrLayer: PatchOrLayer {
        .patch(self.patch)
    }
}

extension LayerNodeViewModel {
    var patchOrLayer: PatchOrLayer {
        .layer(self.layer)
    }
}

extension NodeKind {
    var patchOrLayer: PatchOrLayer? {
        .from(nodeKind: self)
    }
}

extension NodeViewModel {
    var patchOrLayer: PatchOrLayer? {
        self.kind.patchOrLayer
    }
}

extension PatchOrLayer {
    
    @MainActor
    func createDefaultNode(id: NodeId,
                           activeIndex: ActiveIndex,
                           graphDelegate: GraphState) -> NodeViewModel? {
        switch self {
        case .patch(let patch):
            return patch.defaultNode(id: id,
                                     position: .zero,
                                     zIndex: .zero,
                                     graphDelegate: graphDelegate)
        case .layer(let layer):
            return layer.defaultNode(id: id,
                                     position: .zero,
                                     zIndex: .zero,
                                     graphDelegate: graphDelegate)
        }
    }
    
    
    // Only Patches and Layers have static NodeDefinitons
    var graphNode: (any NodeDefinition.Type)? {
        switch self {
        case .patch(let patch):
            return patch.graphNode
        case .layer(let layer):
            return layer.graphNode
        }
    }
}
