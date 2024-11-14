# SwiftDataX

SwiftDataX brings extended features to SwiftData like an `NSFetchedResultsController` and `@Query` with dynamic predicate and sort descriptors.

It currently uses a private notification for model context changes which could be a problem for app review but probably not since it is just a string and not a private method.
