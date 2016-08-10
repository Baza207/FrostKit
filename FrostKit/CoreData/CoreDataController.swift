//
//  CoreDataController.swift
//  FrostKit
//
//  Created by James Barrow on 18/06/2016.
//  Copyright © 2016-Current James Barrow - Frostlight Solutions. All rights reserved.
//

import Foundation
import CoreData

// Needs to be a subclass of NSObject to allow it to be used with @IBOutlet
public class CoreDataController: NSObject {
    
    // MARK: - Properties
    
    public var entityName: String! { return nil }
    public var sectionNameKeyPath: String? { return nil }
    public var cacheName: String? { return nil }
    public var sortDescriptors: [NSSortDescriptor] { return [NSSortDescriptor]() }
    public var predicate: NSPredicate? { return nil }
    private var _fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    public var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let context = CoreDataProxy.shared.managedObjectContextMain!
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        // Edit the entity name as appropriate.
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)
        fetchRequest.entity = entity
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Set the sort descriptors
        fetchRequest.sortDescriptors = sortDescriptors
        
        // Set the predicate
        fetchRequest.predicate = predicate
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try aFetchedResultsController.performFetch()
        } catch let error as NSError {
            NSLog("Fetch error: \(error.localizedDescription)\n\(error)")
        }
        
        return _fetchedResultsController!
    }
    
}
