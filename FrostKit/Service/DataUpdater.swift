//
//  DataUpdater.swift
//  FrostKit
//
//  Created by James Barrow on 26/01/2015.
//  Copyright (c) 2015 Frostlight Solutions. All rights reserved.
//

import UIKit

public class DataUpdater: NSObject {

    let requestStore = RequestStore()
    @IBOutlet var viewController: UIViewController! {
        didSet {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: "refreshControlTriggered:", forControlEvents: .ValueChanged)
            refreshControl.tintColor = FrostKit.shared.tintColor
            
            if let tableViewController = viewController as? UITableViewController {
                tableViewController.refreshControl = refreshControl
            } else if let collectionViewController = viewController as? UICollectionViewController {
                collectionViewController.refreshControl = refreshControl
            }
        }
    }
    @IBOutlet var tableView: UITableView? {
        didSet {
            if let tableView = self.tableView {
                tableView.estimatedRowHeight = 44
                if UIDevice.SystemVersion.majorVersion >= 8 {
                    tableView.rowHeight = UITableViewAutomaticDimension
                }
                updateTableFooter()
            }
        }
    }
    @IBOutlet var collectionView: UICollectionView?
    @IBOutlet var segmentedControl: UISegmentedControl?
    var currentSegmentIndex: Int {
        if let segmentedControl = self.segmentedControl {
            if segmentedControl.selectedSegmentIndex != UISegmentedControlNoSegment {
                return segmentedControl.selectedSegmentIndex
            }
        }
        return 1
    }
    lazy var segmentSectionDictionarys = Array<NSDictionary>()
    lazy var baseDataStore = DataStore()
    var dataStore: DataStore {
        return baseDataStore
    }
    
    convenience public init(viewController: UIViewController, tableView: UITableView) {
        self.init()
        
        self.viewController = viewController
        self.tableView = tableView
    }
    
    convenience public init(viewController: UIViewController, collectionView: UICollectionView) {
        self.init()
        
        self.viewController = viewController
        self.collectionView = collectionView
    }
    
    func viewWillAppear(animated: Bool) {
        endRefreshing()
        updateData()
    }
    
    func updateTableFooter(count: Int = 0) {
        if let tableView = self.tableView {
            // If the data array is empty, add a table footer with a label telling the user
            if count <= 0 {
                let noContentLabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 44))
                noContentLabel.backgroundColor = UIColor.clearColor()
                noContentLabel.text = FKLocalizedString("NO_CONTENT_FOUND", comment: "No Content Found")
                noContentLabel.textColor = UIColor.lightGrayColor()
                noContentLabel.textAlignment = .Center
                noContentLabel.font = UIFont.systemFontOfSize(14)
                noContentLabel.minimumScaleFactor = 0.5
                tableView.tableFooterView = noContentLabel
            } else {
                let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 0))
                footerView.backgroundColor = UIColor.clearColor()
                tableView.tableFooterView = footerView
            }
        }
    }
    
    // MARK: - Section Dictionary Getter / Setter Methods
    
    func sectionDictionaryForSegment(segment: Int) -> NSDictionary? {
        if segment != NSNotFound && segment < segmentSectionDictionarys.count {
            return segmentSectionDictionarys[segment]
        } else {
            return segmentSectionDictionarys.first
        }
    }
    
    func currentSectionDictionary() -> NSDictionary? {
        return sectionDictionaryForSegment(currentSegmentIndex)
    }
    
    func setSectionDictionary(sectionDictionary: NSDictionary, segment: Int) {
        if segment != NSNotFound {
            while segment >= segmentSectionDictionarys.count {
                segmentSectionDictionarys.append(NSDictionary())
            }
            segmentSectionDictionarys[segment] = sectionDictionary
        }
    }
    
    func setSectionDictionarys(sectionDictionarys: [NSDictionary]) {
        for index in 0..<sectionDictionarys.count {
            setSectionDictionary(sectionDictionarys[index], segment: index)
        }
    }
    
    func setSectionDictionary(sectionDictionary: NSDictionary) {
        setSectionDictionarys([sectionDictionary])
    }
    
    // MARK: - Data Store Getter / Setter Methods
    
    func setDataStore(dataStore: DataStore, segment: Int) -> Bool {
        var shouldReloadData = false
        
        if currentSegmentIndex == segment {
            if baseDataStore.isEqualToDataStore(dataStore) == false {
                baseDataStore = dataStore
                shouldReloadData = true
            }
        }
        
        if shouldReloadData == true {
            updateTableFooter(count: dataStore.count)
            reloadData()
        }
        return shouldReloadData
    }
    
    // MARK: - Update and Load Methods
    
    func refreshControlTriggered(sender: UIRefreshControl) {
        updateData()
    }
    
    func updateData() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            self.updateDataStoreForSegment(self.currentSegmentIndex)
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                // TODO: Call updatedData() function in the current view controller.
            })
        })
    }
    
    func updateDataStoreForSegment(segment: Int) {
        if let sectionDict = sectionDictionaryForSegment(segment) {
            let urlString = sectionDict["url"] as String
            // Load local data if available
            if let localDataStore = UserStore.current.dataStoreForURL(urlString) {
                loadDataStore(localDataStore, segment: segment)
            }
            // TODO: Add paged int if available
            let request = ServiceClient.request(Router.Custom(urlString, nil), completed: { (object, error) -> () in
                self.requestStore.removeRequestFor(urlString)
                if let anError = error {
                    NSLog("Data Updater Failure: %@", anError.localizedDescription)
                } else {
                    if let dataStore = object {
                        self.loadDataStore(dataStore, segment: segment)
                    }
                }
                self.endRefreshing()
            })
            self.requestStore.addRequest(request, urlString: urlString)
        }
    }
    
    func loadDataStore(dataStore: DataStore, segment: Int) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            self.setDataStore(dataStore, segment: segment)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                // TODO: Call loadedData() function in the current view controller.
            })
        }
    }
    
    func reloadData() {
        if let tableView = self.tableView {
            tableView.reloadData()
        } else if let collectionView = self.collectionView {
            collectionView.reloadData()
        }
    }
    
    func endRefreshing() {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            var refreshControl: UIRefreshControl?
            if let tableViewController = self.viewController as? UITableViewController {
                refreshControl = tableViewController.refreshControl
            } else if let collectionViewController = self.viewController as? UICollectionViewController {
                refreshControl = collectionViewController.refreshControl
            }
            
            if refreshControl?.refreshing == true {
                refreshControl?.endRefreshing()
            }
        })
    }
    
    // MARK: - Segmented Control Methods
    
    func showSegmentedControl() {
        if let tableView = self.tableView {
            if segmentedControl?.hidden == true {
                if let headerView = tableView.tableHeaderView {
                    tableView.tableHeaderView = nil
                    segmentedControl?.hidden = false
                    headerView.frame = CGRect(x: 0, y: 0, width: headerView.bounds.width, height: 88)
                    tableView.tableHeaderView = headerView
                }
            }
        }
    }
    
    func hideSegmentedControl() {
        if let tableView = self.tableView {
            if segmentedControl?.hidden == false {
                if let headerView = tableView.tableHeaderView {
                    tableView.tableHeaderView = nil
                    segmentedControl?.hidden = true
                    headerView.frame = CGRect(x: 0, y: 0, width: headerView.bounds.width, height: 44)
                    tableView.tableHeaderView = headerView
                }
            }
        }
    }
    
    // TODO: Methods for getting a segments filters
    
    func updateSegmentedControlTitles() {
        // TODO: Update according to filters
    }
    
    @IBAction func segmentedControlDidChange(sender: UISegmentedControl) {
        reloadData()
        if let sectionData = currentSectionDictionary() {
            updateData()
        }
    }
    
}
