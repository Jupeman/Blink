import Foundation

struct TransferProgress: Equatable, Sendable {
    let filename: String
    let percentage: Int
    let transferred: String
    let speed: String
    let eta: String
}
