import os
import ShotCore

/// Logger for the workflow / automation module.
enum WorkflowLog {
    static let logger = Logger(subsystem: Log.subsystem, category: "workflow")
}
