import Foundation

/// One screenshot file. Identified by its file URL; holds no image data.
struct Screenshot: Identifiable, Equatable {
    let url: URL
    let createdAt: Date

    var id: URL { url }
}
