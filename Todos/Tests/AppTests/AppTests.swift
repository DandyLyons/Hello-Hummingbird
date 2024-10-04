import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import HummingbirdTodos

@Suite
struct AppTests {
    struct TestArguments: AppArguments {
        let hostname = "127.0.0.1"
        let port = 0
        let logLevel: Logger.Level? = .trace
    }

    struct CreateRequest: Encodable {
        let title: String
        let order: Int?
    }
    struct UpdateRequest: Encodable {
        let title: String? 
        let order: Int? 
        let completed: Bool? 
    }
    // MARK: test helpers
    func create(title: String, order: Int? = nil, client: some TestClientProtocol) async throws -> Todo {
        let request = CreateRequest(title: title, order: order)
        let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
        return try await client.execute(uri: "/todos", method: .post, body: buffer) { response in 
            #expect(response.status == .created)
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    func get(id: UUID, client: some TestClientProtocol) async throws -> Todo? {
        try await client.execute(uri: "/todos/\(id)", method: .get) { response in 
            // either the get request returned a 200 status or it didn't return a Todo
            #expect(response.status == .ok || response.body.readableBytes == 0)
            if response.body.readableBytes > 0 {
                return try JSONDecoder().decode(Todo.self, from: response.body)
            } else {
                return nil
            }
        }
    }

    func list(client: some TestClientProtocol) async throws -> [Todo] {
        try await client.execute(uri: "/todos", method: .get) { response in 
            #expect(response.status == .ok)
            return try JSONDecoder().decode([Todo].self, from: response.body)
        }
    }

    func patch(id: UUID, title: String? = nil, order: Int? = nil, completed: Bool? = nil, client: some TestClientProtocol) async throws -> Todo? {
        let request = UpdateRequest(title: title, order: order, completed: completed)
        let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
        return try await client.execute(uri: "/todos/\(id)", method: .patch, body: buffer) { response in 
            #expect(response.status == .ok)
            if response.body.readableBytes > 0 {
                return try JSONDecoder().decode(Todo.self, from: response.body)
            } else {
                return nil
            }
        }
    }

    func delete(id: UUID, client: some TestClientProtocol) async throws -> HTTPResponse.Status {
        try await client.execute(uri: "/todos/\(id)", method: .delete) { response in 
            response.status
        }
    }

    func deleteAll(client: some TestClientProtocol) async throws  {
        try await client.execute(uri: "/todos", method: .delete) { _ in }
    }
    
    // MARK: Tests
    @Test func testApp() async throws {
        let args = TestArguments()
        let app = try await buildApplication(args)
        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.body == ByteBuffer(string: "Hello!"))
            }
        }
    }

    @Test func create() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in 
            let todo = try await self.create(title: "My first todo", client: client)
            #expect(todo.title == "My first todo")
        }
    }

    @Test func patch() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            // Create todo
            let todo = try await create(title: "Deliver parcels to James", client: client)

            // rename it
            let patchResult1 = try await patch(id: todo.id, title: "Deliver parcels to Claire", client: client)
            let getResultAfterPatch1 = try await get(id: todo.id, client: client)
            #expect(patchResult1 == getResultAfterPatch1)
            #expect(getResultAfterPatch1?.title == "Deliver parcels to Claire")

            // set it to completed
            let patchResult2 = try await patch(id: todo.id, completed: true, client: client)
            let getResultAfterPatch2 = try await get(id: todo.id, client: client)
            #expect(patchResult2 == getResultAfterPatch2)
            #expect(getResultAfterPatch2?.completed == true)

            // revert changes
            let patchResult3 = try await patch(id: todo.id, title: "Deliver parcels to James", completed: false, client: client)
            let getResultAfterPatch3 = try await get(id: todo.id, client: client)
            #expect(patchResult3 == getResultAfterPatch3)
            #expect(getResultAfterPatch3?.title == "Deliver parcels to James")
            #expect(getResultAfterPatch3?.completed == false)

        }
    }

    @Test func testDeletingTodoTwiceReturnsBadRequest() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in 
            let todo = try await create(title: "one", client: client)
            let deleteStatus1 = try await delete(id: todo.id, client: client)
            #expect(deleteStatus1 == .ok)
            let deleteStatus2 = try await delete(id: todo.id, client: client)
            #expect(deleteStatus2 == .badRequest)
        }
    }
    @Test func testGettingTodoWithInvalidUUIDReturnsNil() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in 
            let get = try await get(id: UUID(), client: client)
            #expect(get == nil)
        }
    }
    @Test func test30ConcurrentlyCreatedTodosAreAllCreated() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in 
            for num in 0..<30 {
                _ = try await create(title: String("\(num)"), client: client)
            }
            let allTodos = try await list(client: client)
            #expect(allTodos.count == 30)
        }
    }
    @Test func testUpdatingNonExistentTodoReturnsBadRequest() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in 
            
        }
    }
}
