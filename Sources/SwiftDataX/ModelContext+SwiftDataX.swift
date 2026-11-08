import Foundation
import SwiftData

extension ModelContext {
    
    // when deelting unsaved model the context doesnt have previous model in deleted so need to use notificaiton info to know
    public static let didChangeX = NSNotification.Name(rawValue: "_SwiftDataModelsChangedInContextNotificationPrivate") // what @Query observes.
    
//    public static let willProcessPendingChangesX = NSNotification.Name(rawValue: "SwiftDataXModelContextWillProcessPendingChangesNotification")
    
// no longer needed since changing to use the notification info instead of current context state
//    public func notifyAndProcessPendingChanges() {
//        // Post the custom notification immediately
//        NotificationCenter.default.post(
//            name: Self.willProcessPendingChangesX,
//            object: self,
//            userInfo: nil
//        )
//        processPendingChanges()
//    }
}
