//
//  SwiftFrameTests.swift
//  SwiftFrameTests
//
//  Created by Nicholas Hurden on 3/10/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import XCTest
@testable import SwiftFrame

// Todos

struct AddTodo: Action {
    static var name = "AddTodo"
    let name: String
}

struct DoNothing: Action {
    static var name = "DoNothing"
}

struct AppState {
    var todos: [String] = []
}
extension AppState: Equatable {}

func ==(lhs: AppState, rhs: AppState) -> Bool {
    return lhs.todos == rhs.todos
}

class SwiftFrameTests: XCTestCase {
    func todoStore() -> Store<AppState> {
        let store = Store(initialState: AppState())

        store.registerEventState(actionClass: DoNothing.self) { (state, action) in
            state
        }
        
        return store
    }
    
    func testTodoSimple() {
        let store = todoStore()

        store.registerEventState(actionClass: AddTodo.self) { (state, action) in
            var s = state
            s.todos.append(action.name)
            return s
        }

        store.dispatch(AddTodo(name: "Do Stuff"))
        store.dispatch(DoNothing())
        store.dispatch(AddTodo(name: "Do Stuff"))

        XCTAssert(store.state.value.todos.contains("Do Stuff"))
        XCTAssertEqual(store.state.value.todos.count, 2)
    }

    func testTodoEffects() {
        let store = todoStore()

        enum CounterAction {
            case increment
        }

        store.registerEventEffects(actionClass: AddTodo.self) { (coeffects, action) in
            let state = coeffects["state"] as? AppState
            var newState = state ?? AppState()
            newState.todos.append(action.name)

            return [ "counter": CounterAction.increment,
                     "state": newState ]
        }

        var actionsAdded = 0
        store.registerEffect(key: "counter") { action in
            if let action = action as? CounterAction {
                switch action {
                case .increment:
                    actionsAdded += 1
                }
            }
        }

        store.dispatch(AddTodo(name: "First"))
        store.dispatch(AddTodo(name: "Second"))
        store.dispatch(AddTodo(name: "Third"))

        XCTAssert(store.state.value.todos.contains("First"))
        XCTAssert(store.state.value.todos.contains("Second"))
        XCTAssert(store.state.value.todos.contains("Third"))
        XCTAssertEqual(store.state.value.todos.count, 3)
        XCTAssertEqual(actionsAdded, 3)
    }

    // An alternate way to do the above counter example using the `after` interceptor instead of explicit effects
    func testTodoAfterEffects() {
        let store = todoStore()

        var actionsAdded = 0
        let inc = store.after(actionClass: AddTodo.self) { state, action in
            actionsAdded += 1
        }

        store.registerEventState(actionClass: AddTodo.self, interceptors: [inc]) { (state, action) in
            var s = state
            s.todos.append(action.name)
            return s
        }

        store.dispatch(AddTodo(name: "First"))
        store.dispatch(AddTodo(name: "Second"))
        store.dispatch(AddTodo(name: "Third"))

        XCTAssert(store.state.value.todos.contains("First"))
        XCTAssert(store.state.value.todos.contains("Second"))
        XCTAssert(store.state.value.todos.contains("Third"))
        XCTAssertEqual(store.state.value.todos.count, 3)
        XCTAssertEqual(actionsAdded, 3)
    }

    func testTodosDeduplicate() {
        let store = todoStore()

        let dedup = store.enrich(actionClass: AddTodo.self) { state, action in
            let newTodos = Array(Set(state.todos))
            return AppState(todos: newTodos)
        }
        
        store.registerEventState(actionClass: AddTodo.self, interceptors: [dedup]) { (state, action) in
            var s = state
            s.todos.append(action.name)
            return s
        }

        store.dispatch(AddTodo(name: "First"))
        store.dispatch(AddTodo(name: "Second"))
        store.dispatch(AddTodo(name: "Third"))
        store.dispatch(AddTodo(name: "First"))
        store.dispatch(AddTodo(name: "Second"))
        store.dispatch(AddTodo(name: "Third"))
        store.dispatch(AddTodo(name: "First"))
        store.dispatch(AddTodo(name: "Second"))
        store.dispatch(AddTodo(name: "Third"))

        XCTAssert(store.state.value.todos.contains("First"))
        XCTAssert(store.state.value.todos.contains("Second"))
        XCTAssert(store.state.value.todos.contains("Third"))
        XCTAssertEqual(store.state.value.todos.count, 3)
    }
}
