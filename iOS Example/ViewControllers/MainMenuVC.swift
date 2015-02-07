//
//  MainMenuVC.swift
//  iOS Example
//
//  Created by James Barrow on 02/10/2014.
//  Copyright (c) 2014-2015 James Barrow - Frostlight Solutions. All rights reserved.
//

import UIKit
import FrostKit

class MainMenuVC: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Regiester for developer tools
        DeveloperTools.registerViewController(self)
        
        self.clearsSelectionOnViewWillAppear = true
    }
    
    // MARK: - Table view data source
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
}
