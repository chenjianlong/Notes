//
//  LocationAttachmentViewController.swift
//  Notes-iOS
//
//  Created by chenjianlong on 2017/10/18.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

let defaultCoordinate = CLLocationCoordinate2D(latitude: -42.882743, longitude: 147.330234)

class LocationAttachmentViewController: UIViewController, AttachmentViewer, MKMapViewDelegate {
    @IBOutlet weak var mapView : MKMapView?
    @IBOutlet weak var showCurrentLocationButton: UIBarButtonItem!
    
    var  attachmentFile : FileWrapper?
    var document : Document?
    let locationManager = CLLocationManager()
    let locationPinAnnotation = MKPointAnnotation()
    
    var pinIsVisible : Bool {
        return self.mapView!.annotations.contains(where: {
            (annotation) -> Bool in
            return annotation is MKPointAnnotation
        })
    }

    @IBAction func showCurrentLocation(_ sender: Any) {
        self.mapView?.setUserTrackingMode(.follow, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.requestWhenInUseAuthorization()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        locationPinAnnotation.title = "Drag to place"
        self.showCurrentLocationButton?.isEnabled = false
        if let data = attachmentFile?.regularFileContents {
            do {
                guard let loadedData = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as? [String: CLLocationDegrees] else {
                    return
                }
                
                if let latitude = loadedData["lat"], let longitude = loadedData["long"] {
                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    locationPinAnnotation.coordinate = coordinate
                    self.mapView?.addAnnotation(locationPinAnnotation)
                }
            } catch let error as NSError {
                NSLog("Failed to load location: \(error)")
            }
            
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(LocationAttachmentViewController.addAttachmentAndClose))
            self.navigationItem.rightBarButtonItem = doneButton
        } else {
            // edit mode
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(LocationAttachmentViewController.closeAttachmentWithoutSaving))
            self.navigationItem.leftBarButtonItem = cancelButton
            
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(LocationAttachmentViewController.addAttachmentAndClose))
            self.navigationItem.rightBarButtonItem = doneButton
            self.mapView?.delegate = self
        }
    }
    
    func addAttachmentAndClose() {
        if self.pinIsVisible {
            let location = self.locationPinAnnotation.coordinate
            let locationDict : [String: CLLocationDegrees] = [
                "lat": location.latitude,
                "long": location.longitude
            ]
            
            do {
                let locationData = try JSONSerialization.data(withJSONObject: locationDict, options: JSONSerialization.WritingOptions())
                let locationName : String
                let newFileName = "\(arc4random()).json"
                if attachmentFile != nil {
                    locationName = attachmentFile!.preferredFilename ?? newFileName
                    try self.document?.deleteAttachment(attachment: self.attachmentFile!)
                } else {
                    locationName = newFileName
                }
                
                try self.document?.addAttachmentWithData(data: locationData, name: locationName)
            } catch let error as NSError {
                NSLog("Failed to save location: \(error)")
            }
        }
        
        self.dismiss(animated: true, completion: nil)
        //self.presentedViewController?.dismiss(animated: true, completion: nil)
    }
    
    func closeAttachmentWithoutSaving() {
        self.dismiss(animated: true, completion: nil)
        //self.presentedViewController?.dismiss(animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        self.showCurrentLocationButton?.isEnabled = true
        if self.pinIsVisible == false {
            let coordinate = userLocation.coordinate
            locationPinAnnotation.coordinate = coordinate
            self.mapView?.addAnnotation(locationPinAnnotation)
            self.mapView?.selectAnnotation(locationPinAnnotation, animated: true)
        }
    }
    
    func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
        NSLog("Failed to get user location: \(error)")
        self.showCurrentLocationButton?.isEnabled = false
        if self.pinIsVisible == false {
            locationPinAnnotation.coordinate = defaultCoordinate
            self.mapView?.addAnnotation(locationPinAnnotation)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseID = "Location"
        if let pointAnnotation = annotation as? MKPointAnnotation {
            if let existingAnnotation = self.mapView?.dequeueReusableAnnotationView(withIdentifier: reuseID) {
                existingAnnotation.annotation = annotation
                return existingAnnotation
            } else {
                let annotationView = MKPinAnnotationView(annotation: pointAnnotation, reuseIdentifier: reuseID)
                annotationView.isDraggable = true
                annotationView.canShowCallout = true
                return annotationView
            }
        } else {
            return nil
        }
    }
}
