import Foundation

/// A simple to-do item the user can manage.
struct TodoTask: Identifiable {
    let id: UUID
    var title: String
    var isDone: Bool
}

/// The app's in-memory store of tasks.
final class TaskStore {
    static let shared = TaskStore()
    private(set) var tasks: [TodoTask] = []

    /// Add a new task with the given title and return it.
    func addTask(title: String) -> TodoTask {
        let task = TodoTask(id: UUID(), title: title, isDone: false)
        tasks.append(task)
        return task
    }

    /// Mark the task with the given title as completed.
    func completeTask(named title: String) {
        if let index = tasks.firstIndex(where: { $0.title == title }) {
            tasks[index].isDone = true
        }
    }

    /// Return the number of tasks still open.
    func openTaskCount() -> Int {
        tasks.filter { !$0.isDone }.count
    }
}
