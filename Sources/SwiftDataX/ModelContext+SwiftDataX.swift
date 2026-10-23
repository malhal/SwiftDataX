import Foundation
import SwiftData

extension ModelContext {
    
    //doesnt send delete for unsaved model
    public static let didChangeX = NSNotification.Name(rawValue: "_SwiftDataModelsChangedInContextNotificationPrivate") // what @Query observes.
    
    public static let willProcessPendingChangesX = NSNotification.Name(rawValue: "SwiftDataXModelContextWillProcessPendingChangesNotification")
    
    public func notifyAndProcessPendingChanges() {
        // Post the custom notification immediately
        NotificationCenter.default.post(
            name: Self.willProcessPendingChangesX,
            object: self,
            userInfo: nil
        )
        processPendingChanges()
    }
}
