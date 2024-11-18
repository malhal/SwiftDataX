import Foundation
import SwiftData

extension ModelContext {
    public static let didChangeX = NSNotification.Name(rawValue: "_SwiftDataModelsChangedInContextNotificationPrivate") // what @Query observes.
}
