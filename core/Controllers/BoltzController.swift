import Foundation
import CoreData

public actor BoltzController {
    private let modelName = "BoltzDataModel"
    private static let appGroupIdentifier = Bundle.main.appGroup
    public static let shared = BoltzController()
    let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    public init() {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "\(Self.appGroupIdentifier)") else {
            // Failure here means the App Group is not configured correctly in Xcode.
            fatalError("Could not retrieve shared application group container URL. Check App Group configuration.")
        }
        let storeURL = groupURL.appendingPathComponent("\(self.modelName).sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        container = NSPersistentContainer(name: self.modelName)
        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle the error appropriately, usually by crashing in development
                // but logging and failing gracefully in production.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            logger.info("Successfully loaded persistent store: \(storeDescription.url?.lastPathComponent ?? "Unknown")")
        }
        self.context = container.newBackgroundContext()
        self.context.automaticallyMergesChangesFromParent = true
    }

    /// Creates and saves a new 'BoltzSwaps' object.
    public func create(id: String, data: String, isPending: Bool, xpubHashId: String, invoice: String?) async throws -> BoltzSwap {
        let savedItem: BoltzSwap = try await context.perform {
            let item = BoltzSwap(context: self.context)
            item.id = id
            item.data = data
            item.isPending = isPending
            item.invoice = invoice
            item.xpubHashId = xpubHashId
            try self.context.save()
            return item
        }
        return savedItem
    }

    /// Fetch IDs of 'BoltzSwap' objects by filtering.
    public func fetchIDs(byIsPending: Bool? = nil, byXpubHashId: String? = nil, byInvoice: String? = nil) async throws -> [NSManagedObjectID] {
        let ids: [NSManagedObjectID] = try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: "BoltzSwap")
            var predicates = [NSPredicate]()
            if let isPending = byIsPending {
                predicates.append(NSPredicate(format: "isPending == %@", isPending as NSNumber))
            }
            if let xpubHashId = byXpubHashId {
                predicates.append(NSPredicate(format: "xpubHashId == %@", xpubHashId))
            }
            if let invoice = byInvoice {
                predicates.append(NSPredicate(format: "invoice == %@", invoice))
            }
            if !predicates.isEmpty {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            fetchRequest.resultType = .managedObjectIDResultType
            let ids = try self.context.fetch(fetchRequest)
            return ids
        }
        return ids
    }

    /// Fetch ID of 'BoltzSwap' objects by his id.
    public func fetchID(byId id: String) async throws -> NSManagedObjectID? {
        let item = try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: "BoltzSwap")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            fetchRequest.fetchLimit = 1
            fetchRequest.resultType = .managedObjectIDResultType
            let ids = try self.context.fetch(fetchRequest)
            return ids.first
        }
        return item
    }

    /// Fetch object of a 'BoltzSwap' from his id.
    public func get(with id: NSManagedObjectID) async throws -> BoltzSwap? {
        // objectWithID: efficiently uses in-memory information or the store as needed
        try await context.perform {
            try self.context.existingObject(with: id) as? BoltzSwap
        }
    }

    public func gets(with ids: [NSManagedObjectID]) async throws -> [BoltzSwap] {
        if ids.isEmpty {
            return []
        }
        return try await context.perform {
            try ids.compactMap { id in
                try self.context.existingObject(with: id) as? BoltzSwap
            }
        }
        /*let savedItems: [BoltzSwap] = try await context.perform {
            let fetchRequest: NSFetchRequest<BoltzSwap> = NSFetchRequest<BoltzSwap>(entityName: "BoltzSwap")
            fetchRequest.predicate = NSPredicate(format: "self IN %@", ids)
            fetchRequest.resultType = .managedObjectResultType
            let items = try self.context.fetch(fetchRequest)
            return items
        }
        return savedItems*/
    }

    /// Updates the 'data' attribute of an existing 'BoltzSwap' by its ID.
    public func update(with id: NSManagedObjectID, newData: String? = nil, newIsPending: Bool? = nil) async throws {
        try await context.perform {
            let object = self.context.object(with: id)
            guard let boltzSwap = object as? BoltzSwap else {
                // It's good practice to check if the object exists and is the correct type.
                throw NSError(domain: "BoltzControllerError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found or wrong type for given ID"])
            }
            if let newData = newData {
                boltzSwap.data = newData
            }
            if let newIsPending = newIsPending {
                boltzSwap.isPending = newIsPending
            }
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
    /// Deletes an item based on its PersistentID.
    public func delete(with id: NSManagedObjectID) async throws {
        try await context.perform {
            let object = self.context.object(with: id)
            self.context.delete(object)
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
}
