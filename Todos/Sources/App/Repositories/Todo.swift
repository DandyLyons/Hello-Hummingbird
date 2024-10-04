import Foundation
import Hummingbird

struct Todo {
    /// Todo ID
    var id: UUID

    /// Todo Title
    var title: String

    /// sort order number
    var order: Int? 

    /// URL to get this ToDo
    var url: String

    /// if the Todo is completed
    var completed: Bool? 
}

extension Todo: Equatable, Decodable, ResponseEncodable {}
// `ResponseEncodable is provided by Hummingbird and inherits from Encodable`