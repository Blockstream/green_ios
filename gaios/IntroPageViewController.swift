//
//  IntroPageViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/14/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class IntroPageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource
{
    var pageControl = UIPageControl()
    var button:UIButton = UIButton()

    fileprivate lazy var pages: [UIViewController] = {
        return [
            self.getViewController(withIdentifier: "Page1"),
            self.getViewController(withIdentifier: "Page2")
        ]
    }()
    
    fileprivate func getViewController(withIdentifier identifier: String) -> UIViewController
    {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate   = self
        
        if let firstVC = pages.first
        {
            setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        }
        let appearance = UIPageControl.appearance(whenContainedInInstancesOf: [IntroPageViewController.self])
        appearance.pageIndicatorTintColor = UIColor.customTitaniumMedium()
        appearance.currentPageIndicatorTintColor = .white
        configurePageControl()
        addButton()
        addBackButton()
    }
    
    func configurePageControl() {
        // The total number of pages that are available is based on how many available colors we have.
        pageControl = UIPageControl(frame: CGRect(x: 0,y: UIScreen.main.bounds.maxY - 50,width: UIScreen.main.bounds.width,height: 50))
        self.pageControl.numberOfPages = pages.count
        self.pageControl.currentPage = 0
        self.pageControl.tintColor = UIColor.black
        self.pageControl.pageIndicatorTintColor = UIColor.black
        self.pageControl.currentPageIndicatorTintColor = UIColor.white
        self.view.addSubview(pageControl)
    }
    func addBackButton() {
        let back = UIButton(frame: CGRect(x: 0 , y: 0, width: 60, height: 30))
        back.backgroundColor = UIColor.clear
        back.addTarget(self, action:#selector(self.backButtonClicked), for: .touchUpInside)
        self.view.addSubview(back)
        back.setImage(UIImage(named: "backarrow"), for: .normal)
        back.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        if #available(iOS 11, *) {
            let guide = view.safeAreaLayoutGuide
            NSLayoutConstraint(item: back, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 35).isActive = true
            NSLayoutConstraint(item: back, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 35).isActive = true
            NSLayoutConstraint(item: back, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: guide, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 16).isActive = true
            NSLayoutConstraint(item: back, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: guide, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 16).isActive = true
        } else {
            NSLayoutConstraint(item: back, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 35).isActive = true
            NSLayoutConstraint(item: back, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 35).isActive = true
            NSLayoutConstraint(item: back, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 16).isActive = true
            NSLayoutConstraint(item: back, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 16).isActive = true
        }
        back.translatesAutoresizingMaskIntoConstraints = false

    }

    @objc func backButtonClicked(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    func addButton() {
        button = UIButton(frame: CGRect(x: 0 , y: 0, width: 60, height: 30))
        button.backgroundColor = UIColor.customMatrixGreen()
        button.setTitle("Got it", for: UIControlState.normal)
        button.addTarget(self, action:#selector(self.buttonClicked), for: .touchUpInside)
        self.view.addSubview(button)
        button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 45).isActive = true
        NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 16).isActive = true
        if #available(iOS 11, *) {
            NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: self.view.safeAreaLayoutGuide, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -16).isActive = true
        } else {
            NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -16).isActive = true
        }
        NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -16).isActive = true
    }
    var clickCount: Int = 0

    @objc func buttonClicked(_ sender: UIButton) {
        if (clickCount == 0) {
            button.setTitle("Create Wallet", for: UIControlState.normal)
            let viewController = pages[1]
            setViewControllers([viewController], direction:
                UIPageViewControllerNavigationDirection.forward, animated: true, completion: nil)
            self.pageControl.currentPage = 1
        } else {
            self.performSegue(withIdentifier: "next", sender: nil)
        }
        clickCount += 1
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0          else { return pages.last }
        
        guard pages.count > previousIndex else { return nil        }
        
        return pages[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }
        
        let nextIndex = viewControllerIndex + 1
        
        guard nextIndex < pages.count else { return pages.first }
        
        guard pages.count > nextIndex else { return nil         }
        
        return pages[nextIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        let pageContentViewController = pageViewController.viewControllers![0]
        self.pageControl.currentPage = pages.index(of: pageContentViewController)!
    }
    
    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 2
    }
    
    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 0
    }

}
