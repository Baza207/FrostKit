//
//  CoreDataTableViewController.swift
//  FrostKit
//
//  Created by James Barrow on 18/06/2016.
//  Copyright © 2016 - 2017 James Barrow - Frostlight Solutions. All rights reserved.
//

import UIKit
import CoreData

open class CoreDataTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    // MARK: - Properties
    
    @IBOutlet public weak var dataController: CoreDataController! {
        didSet { dataController.fetchedResultsController.delegate = self }
    }
    
    open var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        return dataController.fetchedResultsController
    }
    
    // MARK: - View lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        clearsSelectionOnViewWillAppear = true
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        fetchAndReloadData()
    }
    
    // MARK: - Table view
    
    open override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let sections = fetchedResultsController.sections, sections.count > section {
            
            let sectionInfo = sections[section]
            return sectionInfo.numberOfObjects
            
        } else {
            return 0
        }
    }
    
    // MARK: - Fetched results controller
    
    open func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.reloadData()
    }
    
    open func fetchAndReloadData() {
        
        // Refresh and reload data
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch let error {
            NSLog("Fetch error: \(error.localizedDescription)\n\(error)")
        }
    }
}
