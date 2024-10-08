import Foundation
import Hummingbird

struct TodoController<Repository: TodoRepository> {
    /// Todo repository
    let repository: Repository

    // return todo endpoints
    var endpoints: RouteCollection<AppRequestContext> {
        return RouteCollection(context: AppRequestContext.self)
            .get(":id", use: get(request:context:))
            .get(use: list(request:context:))
            .post(use: create(request:context:))
            .patch(":id", use: update(request:context:))
            .delete(":id", use: delete(request:context:))
            .delete(use: deleteAll(request:context:))
    }
    

    /// Get todo endpoint
    /// - Parameters:
    ///   - request: the request
    ///   - context: the context of the request
    ///
    /// - Throws: an `HTTPError` if the UUID string is invalid
    /// - Returns:
    /// 
    /// >nil:
    /// > If the endpoint returns nil because it could not find a todo this will automatically return 
    /// a 204 (No Content) HTTP response to the client.
    /// 
    /// >HTTPError:
    /// >This endpoint has a few other features. If it fails to convert the id to a UUID then it throws 
    /// an HTTPError. This is an error that can be converted by the server to a valid HTTP response. If 
    /// the server receives an error it cannot convert to an HTTP response it will return a 500 (Internal 
    /// Server Error) HTTP error to the client.
    @Sendable func get(request: Request, context: some RequestContext) async throws -> Todo? {
        let id = try context.parameters.require("id", as: UUID.self)
        return try await self.repository.get(id: id)
    }

    struct CreateRequest: Decodable {
        let title: String
        let order: Int?
    }
    /// Create todo endpoint
    @Sendable func create(request: Request, context: some RequestContext) async throws -> EditedResponse<Todo> {
        let request = try await request.decode(as: CreateRequest.self, context: context)
        let todo = try await self.repository.create(title: request.title, order: request.order, urlPrefix: "http://localhost:8080/todos/")
        return EditedResponse(status: .created, response: todo) // return 201 status
    }

    /// Get list of todos endpoint
    @Sendable func list(request: Request, context: some RequestContext) async throws -> [Todo] {
        return try await self.repository.list()
    }

    struct UpdateRequest: Decodable {
        let title: String?
        let order: Int? 
        let completed: Bool? 
    }

    /// Update todo endpoint
    @Sendable func update(request: Request, context: some RequestContext) async throws -> Todo? {
        let id = try context.parameters.require("id", as: UUID.self)
        let request = try await request.decode(as: UpdateRequest.self, context: context)
        guard let todo = try await self.repository.update(
            id: id, 
            title: request.title, 
            order: request.order,
            completed: request.completed
        ) else {
            throw HTTPError(.badRequest)
        }
        return todo
    }
    /// Delete todo endpoint
    @Sendable func delete(request: Request, context: some RequestContext) async throws -> HTTPResponse.Status {
        let id = try context.parameters.require("id", as: UUID.self)
        if try await self.repository.delete(id: id) {
            return .ok
        } else {
            return .badRequest
        }
    }

    /// Delete all todos endpoint
    @Sendable func deleteAll(request: Request, context: some RequestContext) async throws -> HTTPResponse.Status {
        try await self.repository.deleteAll()
        return .ok
    }
}