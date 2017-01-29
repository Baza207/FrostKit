//
//  MapController.swift
//  FrostKit
//
//  Created by James Barrow on 29/11/2014.
//  Copyright © 2014 - 2017 James Barrow - Frostlight Solutions. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

///
/// The map controller handles basic map options and controls for a `MKMapView`. It provides automatic functions for adding/removing annotations, finding directions, zooming the map view and searching the annotations plotted on the map.
///
/// This class is designed to be subclassed if more specific actions, such a refining the standard search or customising the annotations plotted.
///
open class MapController: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
    
    private let minimumZoomArc = 0.007  //approximately 1/2 mile (1 degree of arc ~= 69 miles)
    private let maximumDegreesArc: Double = 360
    private let annotationRegionPadFactor: Double = 1.15
    /// The reuse identifier for the annotations for the map view. This should be overriden when subclassing.
    open var identifier: String {
        return "FrostKitAnnotation"
    }
    
    /// Dictates if the users location has been initially plotted.
    public var hasPlottedInitUsersLocation = false
    /// Dictates if the users location was not able to be plotted, due permissions issues, etc.
    public var failedToPlotUsersLocation = false
    /// The view controller related to the map controller.
    @IBOutlet public weak var viewController: UIViewController!
    /// The map view related to the map controller.
    @IBOutlet public weak var mapView: MKMapView? {
        didSet {
            mapView?.userTrackingMode = .follow
            mapView?.showsUserLocation = true
            if autoAssingDelegate == true {
                mapView?.delegate = self
            }
            
            if shouldRequestLocationServices {
                
                if locationManager == nil {
                    locationManager = CLLocationManager()
                    locationManager?.delegate = self
                }
                
                MapController.requestAccessToLocationServices(locationManager!)
            }
        }
    }
    
    /// Used for plotting all annotations to ditermine annotation clustering.
    public let offscreenMapView = MKMapView(frame: CGRect())
    /// Private instance of map view, that returns the offscreen map view only if clustering is on.
    private var _mapView: MKMapView? {
        if shouldUseAnnotationClustering {
            return offscreenMapView
        } else {
            return mapView
        }
    }
    
    /// Determins if the map controller should cluster the annotations on the map, or plot them all directly. THe default is `true`.
    @IBInspectable public var shouldUseAnnotationClustering: Bool = true
    /**
     This value controls the number of off screen annotations displayed.
     
     A bigger number means more annotations, less change of seeing annotation views pop in, but decreaced performance.
     
     A smaller number means fewer annotations, more chance of seeing annotation views pop in, but better performance.
    */
    @IBInspectable public var marginFactor: Double = 2
    /**
     Adjust this based on the deimensions of your annotation views.
     
     Bigger number more aggressively coalesce annotations (fewer annotations displayed, but better performance).
     
     Numbers too small result in overlapping annotation views and too many annotations on screen.
    */
    @IBInspectable public var bucketSize: Double = 60
    private var currentlyUpdatingVisableAnnotations = false
    private var shouldTryToUpdateVisableAnnotationsAgain = false
    /// Refers to if the map controller should auto assign itself to the map view as a delegate.
    // swiftlint:disable weak_delegate
    @IBInspectable var autoAssingDelegate: Bool = true {
        didSet {
            if autoAssingDelegate == true {
                mapView?.delegate = self
            }
        }
    }
    
    // swiftlint:enable weak_delegate
    /// `true` if the user is currently being tracked in the map view or `false` if not.
    public var trackingUser: Bool = false {
        didSet {
            if trackingUser == true {
                mapView?.userTrackingMode = .follow
            } else {
                mapView?.userTrackingMode = .none
            }
            
            if let mapViewController = viewController as? MapViewController {
                mapViewController.updateNavigationButtons()
            }
        }
    }
    
    /// Determins if the location manager should request access to location services on setup. By default this is set to `false`.
    @IBInspectable public var shouldRequestLocationServices: Bool = false
    /// The location manager automatically created when assigning the map view to the map controller. It's only use if for getting the user's access to location services.
    private var locationManager: CLLocationManager?
    /// An array of addresses plotted on the map view.
    public var addresses: [Address] {
        return [Address](addressesDict.values)
    }
    
    private var addressesDict = [AnyHashable: Address]()
    
    /// A dictionary of annotations plotted to the map view with the address object as the key.
    public var annotations = [AnyHashable: Any]()
    /// When the map automatically zooms to show all, if this value is set to true, then the users annoation is automatically included in that.
    @IBInspectable public var zoomToShowAllIncludesUser: Bool = true
    private var regionSpanBeforeChange: MKCoordinateSpan?
    let clusterCalculationsQueue = DispatchQueue.global(qos: .userInitiated)
    var cancelClusterCalculations = false
    
    deinit {
        resetMap()
        purgeMap()
    }
    
    /**
    Resets the map controller, clearing the addresses, annotations and removing all annotations and polylines on the map view.
    */
    public func resetMap() {
        
        cancelClusterCalculations = true
        
        addressesDict.removeAll(keepingCapacity: false)
        annotations.removeAll(keepingCapacity: false)
        
        removeAllAnnotations()
        removeAllPolylines()
    }
    
    /**
    Attempt to purge the map view to free up some memory.
    */
    private func purgeMap() {
        
        mapView?.userTrackingMode = .none
        mapView?.showsUserLocation = true
        mapView?.mapType = .standard
        mapView?.delegate = nil
    }
    
    // MARK: - Location Services
    
    public class func requestAccessToLocationServices(_ locationManager: CLLocationManager) {
        
        if let infoDictionary = Bundle.main.infoDictionary {
            
            if infoDictionary["NSLocationAlwaysUsageDescription"] != nil {
                locationManager.requestAlwaysAuthorization()
            } else if infoDictionary["NSLocationWhenInUseUsageDescription"] != nil {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    // MARK: - Plot/Remove Annotations Methods
    
    /**
    Plot an array of addresses to the map view.
     
    - parameter addresses: An array of addresses to plot.
    */
    public func plot(addresses: [Address]) {
        for address in addresses {
            plot(address: address, asBulk: true)
        }
        updateVisableAnnotations()
    }
    
    /**
     Plot an address to the map view.
     
     - parameter address:        An address to plot.
     - parameter asBulk: Tells the controller if this is part of a bulk command. Leave to `false` for better performance.
     */
    public func plot(address: Address, asBulk: Bool = false) {
        if address.isValid == false {
            return
        }
        
        // Update or add the address
        addressesDict[address.key] = address
        
        let annotation: Annotation
        if let currentAnnotation = annotations[address.key] as? Annotation {
            // Annotation already exists, update the address
            currentAnnotation.update(address: address)
            annotation = currentAnnotation
        } else {
            // No previous annotation for this addres, create one
            let newAnnotation = Annotation(address: address)
            annotation = newAnnotation
        }
        
        // Update annotation in cache
        annotations[address.key] = annotation
        
        _mapView?.addAnnotation(annotation)
        
        if asBulk == false {
            updateVisableAnnotations()
        }
    }
    
    /**
    Remove all annotations plotted to the map.
     
    - parameter includingCached: If `true` then the cached annotations dictionary is also cleared.
    */
    public func removeAllAnnotations(includingCached: Bool = false) {
        
        guard let annotations = Array(self.annotations.values) as? [MKAnnotation] else {
            return
        }
        _mapView?.removeAnnotations(annotations)
        
        if includingCached == true {
            self.annotations.removeAll(keepingCapacity: false)
        }
        
        updateVisableAnnotations()
    }
    
    /**
    Clears all of the annotations from the map, including caced, and clears the addresses array.
    */
    public func clearData() {
        removeAllAnnotations(includingCached: true)
        addressesDict.removeAll(keepingCapacity: false)
    }
    
    // MARK: - Annotation Clustering
    
    /**
     This function is automatically called when an address is added or the map region changes.
     
     If you have customised plotting of map points, this should be called, but should not be overriden.
     */
    public final func updateVisableAnnotations() {
        
        if currentlyUpdatingVisableAnnotations == true {
            shouldTryToUpdateVisableAnnotationsAgain = true
            return
        }
        
        currentlyUpdatingVisableAnnotations = true
        shouldTryToUpdateVisableAnnotationsAgain = false
        
        if shouldUseAnnotationClustering {
            
            calculateAndUpdateClusterAnnotations {
                
                self.currentlyUpdatingVisableAnnotations = false
                if self.shouldTryToUpdateVisableAnnotationsAgain == true {
                    self.updateVisableAnnotations()
                }
            }
        } else {
            
            currentlyUpdatingVisableAnnotations = false
            if shouldTryToUpdateVisableAnnotationsAgain == true {
                updateVisableAnnotations()
            }
        }
    }
    
    internal final func calculateAndUpdateClusterAnnotations(_ complete: @escaping () -> Void) {
        
        guard let mapView = self.mapView else {
            complete()
            return
        }
        
        let marginFactor = self.marginFactor
        let bucketSize = self.bucketSize
        
        // Fill all the annotations in the viaable area + a wide margin to avoid poppoing annotation views ina dn out while panning the map.
        let visableMapRect = mapView.visibleMapRect
        let adjustedVisableMapRect = MKMapRectInset(visableMapRect, -marginFactor * visableMapRect.size.width, -marginFactor * visableMapRect.size.height)
        
        // Determine how wide each bucket will be, as a MKMapRect square
        guard let viewController = self.viewController else {
            complete()
            return
        }
        let leftCoordinate = mapView.convert(CGPoint(), toCoordinateFrom: viewController.view)
        let rightCoordinate = mapView.convert(CGPoint(x: bucketSize, y: 0), toCoordinateFrom: viewController.view)
        let gridSize = MKMapPointForCoordinate(rightCoordinate).x - MKMapPointForCoordinate(leftCoordinate).x
        var gridMapRect = MKMapRect(origin: MKMapPoint(x: 0, y: 0), size: MKMapSize(width: gridSize, height: gridSize))
        
        // Condense annotations. with a padding of two squares, around the viableMapRect
        let startX = floor(MKMapRectGetMinX(adjustedVisableMapRect) / gridSize) * gridSize
        let startY = floor(MKMapRectGetMinY(adjustedVisableMapRect) / gridSize) * gridSize
        let endX = floor(MKMapRectGetMaxX(adjustedVisableMapRect) / gridSize) * gridSize
        let endY = floor(MKMapRectGetMaxY(adjustedVisableMapRect) / gridSize) * gridSize
        
        // For each square in the grid, pick one annotation to show
        let offscreenMapView = self.offscreenMapView
        gridMapRect.origin.y = startY
        clusterCalculationsQueue.async {
            
            while MKMapRectGetMinY(gridMapRect) <= endY {
                
                gridMapRect.origin.x = startX
                while MKMapRectGetMinX(gridMapRect) <= endX {
                    
                    self.calculateClusterInGrid(mapView: mapView, offscreenMapView: offscreenMapView, gridMapRect: gridMapRect)
                    
                    if self.cancelClusterCalculations == true {
                        break
                    }
                    
                    gridMapRect.origin.x += gridSize
                }
                
                if self.cancelClusterCalculations == true {
                    break
                }
                
                gridMapRect.origin.y += gridSize
            }
            
            DispatchQueue.main.async {
                self.cancelClusterCalculations = false
                complete()
                return
            }
        }
    }
    
    private final func calculateClusterInGrid(mapView: MKMapView, offscreenMapView: MKMapView, gridMapRect: MKMapRect) {
        
        // Limited to only the use Annotation classes or subclasses
        let semaphore = DispatchSemaphore(value: 0)    // Create semaphore
        var visableAnnotationsInBucket: Set<Annotation>!
        
        DispatchQueue.main.async {
            visableAnnotationsInBucket = mapView.annotations(in: gridMapRect) as! Set<Annotation>
            semaphore.signal()    // Signal that semaphore should complete
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)   // Wait for semaphore
        
        let allAnnotationsInBucket = offscreenMapView.annotations(in: gridMapRect)
        var filteredAllAnnotationsInBucket = Set<Annotation>()
        for object in allAnnotationsInBucket {
            
            if let annotation = object as? Annotation {
                filteredAllAnnotationsInBucket.insert(annotation)
            }
            
            if self.cancelClusterCalculations == true {
                return
            }
        }
        
        // If filteredAllAnnotationsInBucket just contains a single anntation, then plot that
        if filteredAllAnnotationsInBucket.count == 1, let annotation = filteredAllAnnotationsInBucket.first {
            
            DispatchQueue.main.async {
                
                // Give the annotationForGrid a reference to all the annotations it will represent
                annotation.containdedAnnotations = nil
                annotation.clusterAnnotation = nil
                
                mapView.addAnnotation(annotation)
            }
            
            // If filteredAllAnnotationsInBucket contains more than 1 annotation, then get the annotation to show and set relevent details
        } else if filteredAllAnnotationsInBucket.count > 1 {
            
            guard let annotationForGrid = self.calculatedAnnotationInGrid(mapView: mapView, gridMapRect: gridMapRect, allAnnotations: filteredAllAnnotationsInBucket, visableAnnotations: visableAnnotationsInBucket) else {
                return
            }
            
            filteredAllAnnotationsInBucket.remove(annotationForGrid)
            
            DispatchQueue.main.async {
                
                // Give the annotationForGrid a reference to all the annotations it will represent
                annotationForGrid.containdedAnnotations = [Annotation](filteredAllAnnotationsInBucket)
                
                mapView.addAnnotation(annotationForGrid)
            }
            
            // Cleanup other annotations that might be being viewed
            for annotation in filteredAllAnnotationsInBucket {
                
                // Give all the other annotations a reference to the one which is representing then.
                DispatchQueue.main.async {
                    annotation.clusterAnnotation = annotationForGrid
                }
                
                if visableAnnotationsInBucket.contains(annotation) {
                    
                    DispatchQueue.main.async {
                        mapView.removeAnnotation(annotation)
                    }
                }
                
                if self.cancelClusterCalculations == true {
                    return
                }
            }
        }
    }
    
    private final func calculatedAnnotationInGrid(mapView: MKMapView, gridMapRect: MKMapRect, allAnnotations: Set<Annotation>, visableAnnotations: Set<Annotation>) -> Annotation? {
        
        // First, see if one of the annotations we were already showing is in this mapRect
        var annotationForGridSet: Annotation?
        for annotation in visableAnnotations {
            
            if visableAnnotations.contains(annotation) {
                annotationForGridSet = annotation
                break
            }
        }
        
        if annotationForGridSet != nil {
            return annotationForGridSet
        }
        
        // Otherwise, sort the annotations based on their  distance from the center of the grid square,
        // then choose the one closest to the center to show.
        let centerMapPoint = MKMapPoint(x: MKMapRectGetMidX(gridMapRect), y: MKMapRectGetMidY(gridMapRect))
        let sortedAnnotations = allAnnotations.sorted { (object1, object2) -> Bool in
            
            let mapPoint1 = MKMapPointForCoordinate(object1.coordinate)
            let mapPoint2 = MKMapPointForCoordinate(object2.coordinate)
            
            let distance1 = MKMetersBetweenMapPoints(mapPoint1, centerMapPoint)
            let distance2 = MKMetersBetweenMapPoints(mapPoint2, centerMapPoint)
            
            return distance1 < distance2
        }
        
        return sortedAnnotations.first
    }
    
    // MARK: - Zoom Map Methods
    
    /**
     Zoom the map view to a coordinate.
     
     - parameter coordinare: The coordinate to zoom to.
     */
    open func zoom(toCoordinate coordinare: CLLocationCoordinate2D) {
        let point = MKMapPointForCoordinate(coordinare)
        zoom(toMapPoints: [point])
    }
    
    /**
     Zoom the map view to an annotation.
     
     - parameter annotation: The annotation to zoom to.
     */
    open func zoom(toAnnotation annotation: MKAnnotation) {
        zoom(toAnnotations: [annotation])
    }
    
    /**
     Zoom the map to show multiple annotations.
     
     - parameter annotations: The annotations to zoom to.
     */
    open func zoom(toAnnotations annotations: [MKAnnotation]) {
        let count = annotations.count
        if count > 0 {
            var points = [MKMapPoint]()
            for annotation in annotations {
                points.append(MKMapPointForCoordinate(annotation.coordinate))
            }
            zoom(toMapPoints: points)
        }
    }
    
    /**
     Zoom the map to show multiple map points.
     
     - parameter points: Swift array of `MKMapPoints` to zoom to.
     */
    open func zoom(toMapPoints points: [MKMapPoint]) {
        let count = points.count
        let cPoints = UnsafeMutablePointer<MKMapPoint>.allocate(capacity: count)
        cPoints.initialize(from: points)
        zoom(toMapPoints: cPoints, count: count)
        cPoints.deinitialize()
    }
    
    /**
     Zoom the map to show multiple map points.
     
     - parameter points: C array array of `MKMapPoints` to zoom to.
     - parameter count:  The number of points in the C array.
     */
    open func zoom(toMapPoints points: UnsafeMutablePointer<MKMapPoint>, count: Int) {
        let mapRect = MKPolygon(points: points, count: count).boundingMapRect
        var region: MKCoordinateRegion = MKCoordinateRegionForMapRect(mapRect)
        
        if count <= 1 {
            region.span = MKCoordinateSpanMake(minimumZoomArc, minimumZoomArc)
        }
        
        zoom(toRegion: region)
    }
    
    /**
     Zoom the map to show a region.
     
     - parameter region: The region to zoom the map to.
     */
    open func zoom(toRegion region: MKCoordinateRegion) {
        
        var zoomRegion = region
        zoomRegion.span = normalize(regionSpan: region.span)
        mapView?.setRegion(zoomRegion, animated: true)
    }
    
    /**
     Zoom the map to show the users current location.
     */
    open func zoomToCurrentLocation() {
        trackingUser = true
        if let mapView = self.mapView {
            zoom(toCoordinate: mapView.userLocation.coordinate)
        }
    }
    
    /**
     Zoom the map to show all points plotted on the map.
     
     - parameter includingUser: If `true` then the users annotation is also included in the points. If `false` then only plotted points are zoomed to.
     */
    open func zoomToShowAll(includingUser: Bool = true) {
        
        if includingUser == false || zoomToShowAllIncludesUser == false, let annotations = Array(self.annotations.values) as? [MKAnnotation] {
            zoom(toAnnotations: annotations)
        } else if let mapView = _mapView {
            zoom(toAnnotations: mapView.annotations)
        }
    }
    
    /**
     Zooms the map to an address object.
     
     - parameter address: The address object to zoom to.
     */
    open func zoom(toAddress address: Address) {
        plot(address: address)
        
        if let annotation = annotations[address] as? MKAnnotation {
            zoom(toAnnotations: [annotation])
        }
    }
    
    /**
     Zooms the map to a polyline.
     
     - parameter polyline: The polyline to zoom to.
     */
    open func zoom(toPolyline polyline: MKPolyline) {
        zoom(toMapPoints: polyline.points(), count: polyline.pointCount)
    }
    
    // MARK: - Polyline and Route Methods
    
    /**
     Removes all the polylines plotted on the map view.
     */
    public func removeAllPolylines() {
        
        guard let mapView = self.mapView else {
            return
        }
        
        for overlay in mapView.overlays {
            if let polyline = overlay as? MKPolyline {
                mapView.remove(polyline)
            }
        }
    }
    
    /**
     Gets a route between a source and destination.
     
     - parameter source:        The coordinate of the source location.
     - parameter destination:   The coordinate of the destination location.
     - parameter transportType: The transportation type to create the route.
     - parameter complete:      Returns an optional route and error.
     */
    public func routeBetween(sourceCoordinate source: CLLocationCoordinate2D, destinationCoordinate destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .automobile, complete: @escaping (_ route: MKRoute?, _ error: Error?) -> Void) {
        
        let sourcePlacemark = MKPlacemark(coordinate: source, addressDictionary: nil)
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationPlacemark = MKPlacemark(coordinate: destination, addressDictionary: nil)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        routeBetween(sourceMapItem: sourceItem, destinationMapItem: destinationItem, transportType: transportType, complete: complete)
    }
    
    /**
     Gets a route between a source and destination.
     
     - parameter source:        The map item of the source location.
     - parameter destination:   The map item of the destination location.
     - parameter transportType: The transportation type to create the route.
     - parameter complete:      Returns an optional route and error.
     */
    public func routeBetween(sourceMapItem source: MKMapItem, destinationMapItem destination: MKMapItem, transportType: MKDirectionsTransportType = .automobile, complete: @escaping (_ route: MKRoute?, _ error: Error?) -> Void) {
        
        let directionsRequest = MKDirectionsRequest()
        directionsRequest.source = source
        directionsRequest.destination = destination
        directionsRequest.transportType = transportType
        directionsRequest.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: directionsRequest)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NetworkRequestDidBeginNotification), object: nil)
        directions.calculate { (directionsResponse, error) in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NetworkRequestDidCompleteNotification), object: nil)
            complete(directionsResponse?.routes.first, error)
        }
    }
    
    /**
     Gets directions to a coordinate from the users current location.
     
     - parameter coordinate: The coordinate to get directions to.
     - parameter inApp:      If `true` diretions are plotted in-app on the map view. If `false` then the Maps.app is opened with the directions requested.
     */
    public func directionsToCurrentLocation(fromCoordinate coordinate: CLLocationCoordinate2D, inApp: Bool = true) {
        
        let currentLocationItem = MKMapItem.forCurrentLocation()
        let destinationPlacemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        if inApp == true {
            routeBetween(sourceMapItem: currentLocationItem, destinationMapItem: destinationItem, complete: { (route, error) in
                if let anError = error {
                    NSLog("Error getting directions: \(anError.localizedDescription)")
                } else if let aRoute = route {
                    self.plot(route: aRoute)
                }
            })
        } else {
            let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
            MKMapItem.openMaps(with: [currentLocationItem, destinationItem], launchOptions: launchOptions)
        }
    }
    
    /**
     Plots a route as a polyline after removing all previous reotes, and then zoom to display the new route.
     
     - parameter route: The route to plot.
     */
    public func plot(route: MKRoute) {
        mapView?.add(route.polyline, level: .aboveRoads)
    }
    
    // MARK: - Helper Methods
    
    /**
     Normalizes a regions space with the constants preset.
     
     - parameter span: The span to normalize.
     
     - returns: The normalized span.
     */
    public func normalize(regionSpan span: MKCoordinateSpan) -> MKCoordinateSpan {
        
        var normalizedSpan = MKCoordinateSpanMake(span.latitudeDelta * annotationRegionPadFactor, span.longitudeDelta * annotationRegionPadFactor)
        if normalizedSpan.latitudeDelta > maximumDegreesArc {
            normalizedSpan.latitudeDelta = maximumDegreesArc
        } else if normalizedSpan.latitudeDelta < minimumZoomArc {
            normalizedSpan.latitudeDelta = minimumZoomArc
        }
        
        if normalizedSpan.longitudeDelta > maximumDegreesArc {
            normalizedSpan.longitudeDelta = maximumDegreesArc
        } else if normalizedSpan.longitudeDelta < minimumZoomArc {
            normalizedSpan.longitudeDelta = minimumZoomArc
        }
        return normalizedSpan
    }
    
    /**
     Deselects any showing annotation view callout on the map.
     */
    public func deselectAllAnnotations() {
        
        guard let mapView = self.mapView else {
            return
        }
        
        let selectedAnnotations = mapView.selectedAnnotations
        for selectedAnnotation in selectedAnnotations {
            mapView.deselectAnnotation(selectedAnnotation, animated: true)
        }
    }
    
    // MARK: - MKMapViewDelegate Methods
    
    public final func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        return configureAnnotationView(mapView: mapView, viewForAnnotation: annotation)
    }
    
    /**
     Called by `mapView:viewForAnnotation:` in the map controller.
     
     - note: Subclass this method to override the default behaviour.
     
     - parameter mapView:    The map view that requested the annotation view.
     - parameter annotation: The object representing the annotation that is about to be displayed. In addition to your custom annotations, this object could be an `MKUserLocation` object representing the user’s current location.
     
     - returns: The annotation view to display for the specified annotation or nil if you want to display a standard annotation view.
     */
    open func configureAnnotationView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationPinView: MKPinAnnotationView?
        if let myAnnotation = annotation as? Annotation {
            if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView {
                annotationView.annotation = myAnnotation
                annotationPinView = annotationView
            } else {
                let pinView = MKPinAnnotationView(annotation: myAnnotation, reuseIdentifier: identifier)
                if #available(iOSApplicationExtension 9.0, *) {
                    pinView.pinTintColor = MKPinAnnotationView.redPinColor()
                } else {
                    pinView.pinColor = .red
                }
                pinView.animatesDrop = false
                pinView.isHidden = false
                pinView.isEnabled = true
                pinView.canShowCallout = true
                pinView.isDraggable = false
                
                if let anno = annotation as? Annotation, let containdedAnnotations = anno.containdedAnnotations {
                    if anno.containdedAnnotations == nil || containdedAnnotations.count <= 0 {
                        pinView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                    }
                }
                
                annotationPinView = pinView
            }
        }
        
        return annotationPinView
    }
    
    public func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        return calloutAccessoryControlTapped(mapView: mapView, annotationView: view, controlTapped: control)
    }
    
    /**
     Called by `mapView:annotationView:calloutAccessoryControlTapped:` in the map controller.
     
     - note: Subclass this method to override the default behaviour.
     
     - parameter mapView: The map view containing the specified annotation view.
     - parameter view:    The annotation view whose button was tapped.
     - parameter control: The control that was tapped.
     */
    open func calloutAccessoryControlTapped(mapView: MKMapView, annotationView view: MKAnnotationView, controlTapped control: UIControl) {
        if let annotation = view.annotation as? Annotation {
            
            let alertController = UIAlertController(title: annotation.title, message: annotation.subtitle, preferredStyle: .actionSheet)
            let zoomToAlertAction = UIAlertAction(title: FKLocalizedString("ZOOM_TO_", comment: "Zoom to..."), style: .default, handler: { (_) in
                self.zoom(toAnnotation: annotation)
            })
            alertController.addAction(zoomToAlertAction)
            let directionsAlertAction = UIAlertAction(title: FKLocalizedString("DIRECTIONS", comment: "Directions"), style: .default, handler: { (_) in
                self.directionsToCurrentLocation(fromCoordinate: annotation.coordinate)
            })
            alertController.addAction(directionsAlertAction)
            let openInMapsAlertAction = UIAlertAction(title: FKLocalizedString("OPEN_IN_MAPS", comment: "Open in Maps"), style: .default, handler: { (_) in
                self.directionsToCurrentLocation(fromCoordinate: annotation.coordinate, inApp: false)
            })
            alertController.addAction(openInMapsAlertAction)
            let cancelAlertAction = UIAlertAction(title: FKLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: { (_) in
                alertController.dismiss(animated: true, completion: nil)
            })
            alertController.addAction(cancelAlertAction)
            viewController.present(alertController, animated: true, completion: nil)
        }
    }
    
    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return configureOverlayRenderer(mapView: mapView, overlay: overlay)
    }
    
    /**
     Called by `mapView:rendererForOverlay:` in the map controller.
     
     - note: Subclass this method to override the default behaviour.
     
     - parameter mapView: The map view that requested the renderer object.
     - parameter overlay: The overlay object that is about to be displayed.
     
     - returns: The renderer to use when presenting the specified overlay on the map. If you return `nil`, no content is drawn for the specified overlay object.
     */
    open func configureOverlayRenderer(mapView: MKMapView, overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let polylineRenderer = MKPolylineRenderer(polyline: polyline)
            polylineRenderer.strokeColor = UIColor.blue
            polylineRenderer.lineWidth = 4
            polylineRenderer.lineCap = .round
            polylineRenderer.lineJoin = .round
            polylineRenderer.alpha = 0.6
            return polylineRenderer
        }
        return MKOverlayRenderer()
    }
    
    open func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        regionSpanBeforeChange = mapView.region.span
    }
    
    open func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        if let regionSpanBeforeChange = self.regionSpanBeforeChange {
            
            let hasZoomed = !(fabs(mapView.region.span.longitudeDelta - regionSpanBeforeChange.longitudeDelta) < 1.19209290e-7)
            if hasZoomed {
                deselectAllAnnotations()
            }
        }
        
        updateVisableAnnotations()
    }
    
    open func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
        if hasPlottedInitUsersLocation == false {
            hasPlottedInitUsersLocation = true
            failedToPlotUsersLocation = false
            zoomToShowAll()
        }
    }
    
    open func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        
        switch mode {
        case .none:
            trackingUser = false
        case .follow, .followWithHeading:
            trackingUser = true
        }
    }
    
    open func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
        
        hasPlottedInitUsersLocation = false
        failedToPlotUsersLocation = true
        zoomToShowAll()
    }
    
    // MARL: - CLLocationManagerDelegate Methods
    
    open func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        // Set the location manager to nil if not `NotDetermined`. If `NotDetermined` then it is possible the delegate was called before the user has answered.
        if status != .notDetermined {
            self.locationManager = nil
        }
    }
    
    // MARK: - Search Methods
    
    /**
     Performs a predicate search on the addresses dictionary that begins with the search string.
     
     - parameter searchString: The string to search the addresses by name or simple address.
     
     - returns: An array of addresses that meet the predicate search criteria.
     */
    open func searchAddresses(_ searchString: String) -> [Address] {
        return addresses.filter { (address) -> Bool in
            
            let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            
            let nameRange = address.name.range(of: searchString, options: options)
            let addressStringRange = address.addressString.range(of: searchString, options: options)
            
            return nameRange != nil || addressStringRange != nil
        }
    }
}
