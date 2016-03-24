//
//  MapViewController.swift
//  FrostKit
//
//  Created by James Barrow on 06/02/2015.
//  Copyright (c) 2015 Frostlight Solutions. All rights reserved.
//

import UIKit

///
/// The map view controller is made to contain a map view and map controller and allow them to be presnted as a view controller.
///
/// This class is designed to be subclassed if more specific actions, such a updating the addresses or objects to plot.
///
public class MapViewController: UIViewController, UIActionSheetDelegate {
    
    /// The map controller related to the map view controller.
    @IBOutlet public weak var mapController: MapController!
    /// Dictates if the location button should be shown.
    @IBInspectable public var locationButton: Bool = true
    /// Dictates if the search button should be shown. Note: Search is only available on iOS 8+.
    @IBInspectable public var searchButton: Bool = true
    /// The search controller for using in iOS 8+ projects.
    public var searchController: UISearchController!
    /// Overridden by a subclass to define the icon to use in thenavgation bar button item when the `locationButton` is active. Both this and the `inactiveLocationIcon` need to be overriden for the default icon to be overridden.
    public var activeLocationIcon: UIImage? {
        return nil
    }
    /// Overridden by a subclass to define the icon to use in thenavgation bar button item when the `locationButton` is inactive. Both this and the `activeLocationIcon` need to be overriden for the default icon to be overridden.
    public var inactiveLocationIcon: UIImage? {
        return nil
    }
    private var zoomedToShowAll = false
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = FKLocalizedString("MAP", comment: "Map")
        updateNavigationButtons(false)
        
        if NSClassFromString("UISearchController") == nil {
            // iOS 7
            // TODO: Setup UISearchDisplayController for iOS 7.
        } else {
            // iOS 8+
            let searchTableViewController = MapSearchViewController(style: .Plain)
            searchTableViewController.mapController = mapController
            searchController = UISearchController(searchResultsController: searchTableViewController)
            searchController.searchBar.sizeToFit()
            searchController.searchBar.scopeButtonTitles = [FKLocalizedString("MARKERS", comment: "Markers"), FKLocalizedString("LOCATIONS", comment: "Locations")]
            searchController.searchBar.delegate = searchTableViewController
            searchController.delegate = searchTableViewController
            searchTableViewController.searchController = searchController
        }
        
        updateAddresses()
    }
    
    override public func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if zoomedToShowAll == false {
            zoomedToShowAll = true
            mapController.zoomToShowAll()
        }
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Update Methods
    
    /**
    Updates the navigation bar buttons.
    
    - parameter animated: If the buttons should animate when they update.
    */
    public func updateNavigationButtons(animated: Bool = true) {
        var barButtonItems = Array<UIBarButtonItem>()
        if locationButton == true {
            
            let locationButton: UIBarButtonItem
            if let activeLocationIcon = self.activeLocationIcon, inactiveLocationIcon = self.inactiveLocationIcon {
                
                let icon: UIImage
                if mapController.trackingUser == true {
                    icon = activeLocationIcon
                } else {
                    icon = inactiveLocationIcon
                }
                
                locationButton = UIBarButtonItem(image: icon, style: .Plain, target: self, action: #selector(MapViewController.locationButtonPressed(_:)))
                
            } else {
                
                let title: String
                if mapController.trackingUser == true {
                    title = IonIcons.ios_navigate
                } else {
                    title = IonIcons.ios_navigate_outline
                }
                
                locationButton = UIBarButtonItem(title: title, font: UIFont.ionicons(size: 24), verticalOffset: -1, target: self, action: #selector(MapViewController.locationButtonPressed(_:)))
            }
            
            barButtonItems.append(locationButton)
        }
        
        // TODO: Reactivate for iOS 7 when UISearchDisplayController is implimented.
        if UIDevice.SystemVersion.majorVersion >= 8 {
            if searchButton == true {
                let searchButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Search, target: self, action: #selector(MapViewController.searchButtonPressed(_:)))
                barButtonItems.append(searchButton)
            }
        }
        navigationItem.setRightBarButtonItems(barButtonItems, animated: animated)
    }
    
    /**
    Update objects to be plotted on the map. This method is to be overriden by a subclass to specify the specific methods to call new objects from the server.
    */
    public func updateAddresses() {
        // Used to be overriden by a subclass depending on the data service model
    }
    
    // MARK: - Action Methods
    
    /**
    Show the options for the map view controller when the location button is pressed.
    
    - parameter sender: The location button pressed.
    */
    @IBAction public func locationButtonPressed(sender: UIBarButtonItem) {
        if NSClassFromString("UIAlertController") == nil {
            // iOS 7
            let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle: FKLocalizedString("CANCEL", comment: "Cancel"), destructiveButtonTitle: nil, otherButtonTitles: FKLocalizedString("CURRENT_LOCATION", comment: "Current Location"), FKLocalizedString("ALL_LOCATIONS", comment: "All Locations"), FKLocalizedString("CLEAR_DIRECTIONS", comment: "Clear Directions"))
            actionSheet.showFromBarButtonItem(sender, animated: true)
        } else {
            // iOS 8+
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            let currentLocationAlertAction = UIAlertAction(title: FKLocalizedString("CURRENT_LOCATION", comment: "Current Location"), style: .Default, handler: { (action) -> Void in
                self.mapController.zoomToCurrentLocation()
                self.updateNavigationButtons()
            })
            alertController.addAction(currentLocationAlertAction)
            let allLocationsAlertAction = UIAlertAction(title: FKLocalizedString("ALL_LOCATIONS", comment: "All Locations"), style: .Default, handler: { (action) -> Void in
                self.mapController.zoomToShowAll()
            })
            alertController.addAction(allLocationsAlertAction)
            let clearDirectionsAlertAction = UIAlertAction(title: FKLocalizedString("CLEAR_DIRECTIONS", comment: "Clear Directions"), style: .Default, handler: { (action) -> Void in
                self.mapController.removeAllPolylines()
            })
            alertController.addAction(clearDirectionsAlertAction)
            let cancelAlertAction = UIAlertAction(title: FKLocalizedString("CANCEL", comment: "Cancel"), style: .Cancel, handler: { (action) -> Void in
                alertController.dismissViewControllerAnimated(true, completion: nil)
            })
            alertController.addAction(cancelAlertAction)
            presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    /**
    Shows the map search view controller.
    
    - parameter sender: The search button pressed.
    */
    @IBAction public func searchButtonPressed(sender: UIBarButtonItem) {
        if let searchController = self.searchController {
            presentViewController(searchController, animated: true, completion: nil)
        }
    }
    
    // MARK: - UIActionSheetDelegate Methods
    
    public func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        switch buttonIndex {
        case 0:
            mapController.zoomToCurrentLocation()
            updateNavigationButtons()
        case 1:
            mapController.zoomToShowAll()
        case 2:
            mapController.removeAllPolylines()
        default:
            break
        }
    }
    
}
