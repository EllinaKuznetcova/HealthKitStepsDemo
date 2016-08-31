//
//  StepsViewController.swift
//  HealthKitStepsDemo
//
//  Created by Ellina Kuznecova on 31.08.16.
//  Copyright (c) 2015 FlatStack. All rights reserved.
//

import UIKit
import HealthKit

class StepsViewController: UIViewController, UITableViewDataSource {

    @IBOutlet weak private var tableView: UITableView!

    @IBOutlet weak private var activityIndicator: UIActivityIndicatorView!
    
    private let stepCellIdentifier = "stepCell"
    private let totalStepsCellIdentifier = "totalStepsCell"
    
    private let healthKitManager = HealthKitManager.sharedInstance
    
    private var steps = [(NSDate, Double)]()
    
    private let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.startAnimating()
        requestHealthKitAuthorization()
    }

    // MARK: TableView Data Source
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return steps.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(stepCellIdentifier)!
        
        let step = steps[indexPath.row]
        let numberOfSteps = step.1
        
        cell.textLabel!.text = "\(numberOfSteps) steps"
        cell.detailTextLabel?.text = dateFormatter.stringFromDate(step.0)
        
        return cell
    }
}

private extension StepsViewController {
    
    func requestHealthKitAuthorization() {
        let dataTypesToRead = NSSet(objects: healthKitManager.stepsCount!)
        healthKitManager.healthStore?.requestAuthorizationToShareTypes(nil, readTypes: dataTypesToRead as? Set<HKObjectType>, completion: { [unowned self] (success, error) in
            if success {
                self.queryStepsSum()
                self.queryStepsByDay()
            } else {
                print(error!.description)
            }
        })
    }
    
    func queryStepsSum() {
        let sumOption = HKStatisticsOptions.CumulativeSum
        let statisticsSumQuery = HKStatisticsQuery(quantityType: healthKitManager.stepsCount!, quantitySamplePredicate: nil, options: sumOption) { [unowned self] (query, result, error) in
            dispatch_async(dispatch_get_main_queue(), {
                if let sumQuantity = result?.sumQuantity() {
                    let headerView = self.tableView.dequeueReusableCellWithIdentifier(self.totalStepsCellIdentifier)! as UITableViewCell
                    
                    let numberOfSteps = Int(sumQuantity.doubleValueForUnit(self.healthKitManager.stepsUnit))
                    headerView.textLabel!.text = "\(numberOfSteps) total"
                    self.tableView.tableHeaderView = headerView
                }
            })
        }
        healthKitManager.healthStore?.executeQuery(statisticsSumQuery)
    }
    
    func querySteps() {
        let sampleQuery = HKSampleQuery(sampleType: healthKitManager.stepsCount!,
            predicate: nil,
            limit: 100,
            sortDescriptors: nil)
            {  (query, results, error) in
                dispatch_async(dispatch_get_main_queue(), {
//                    if let results = results as? [HKQuantitySample] {
//                        self.steps = results
//                        self.tableView.reloadData()
//                    }
//                    self.activityIndicator.stopAnimating()
//                    self.activityIndicator.hidden = true
                })
        }
        
        healthKitManager.healthStore?.executeQuery(sampleQuery)
    }
    
    func queryStepsByDay() {
        let calendar = NSCalendar.currentCalendar()
        
        let interval = NSDateComponents()
        interval.day = 1
        
        let anchorDate = NSDate().fs_midnightDate()
        guard let quantityType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount) else {
            fatalError("*** Unable to create a step count type ***")
        }
        
        // Create the query
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: nil,
                                                options: .CumulativeSum,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        
        // Set the results handler
        query.initialResultsHandler = { [unowned self]
            query, results, error in
            
            guard let statsCollection = results else {
                // Perform proper error handling here
                fatalError("*** An error occurred while calculating the statistics: \(error?.localizedDescription) ***")
            }
            
            let endDate = NSDate()
            
            guard let startDate = calendar.dateByAddingUnit(.Month, value: -3, toDate: endDate, options: []) else {
                fatalError("*** Unable to calculate the start date ***")
            }
            self.steps = []
            // Plot the weekly step counts over the past 3 months
            statsCollection.enumerateStatisticsFromDate(startDate, toDate: endDate) {statistics, stop in
                
                if let quantity = statistics.sumQuantity() {
                    let date = statistics.startDate
                    let value = quantity.doubleValueForUnit(HKUnit.countUnit())
                    self.steps.append((date, value))
                    print("\(date) \(value)")
                }
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.tableView.reloadData()
                self.activityIndicator.stopAnimating()
                self.activityIndicator.hidden = true
            })
        }
        
        healthKitManager.healthStore?.executeQuery(query)
    }
}