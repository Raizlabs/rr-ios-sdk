//
//  RCHSearchViewController.swift
//  RichRelevanceSDKDemo
//
//  Created by Ariana Antonio on 10/3/16.
//  Copyright © 2016 Raizlabs Inc. All rights reserved.
//

import UIKit

private let reuseIdentifier = "productCell"

class RCHSearchViewController: UIViewController, UISearchBarDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchProductsView: UIView!
    @IBOutlet weak var searchResultsCollectionView: UICollectionView!
    @IBOutlet weak var searchProductsLabel: UILabel!
    @IBOutlet weak var searchProductsImageView: UIImageView!
    @IBOutlet weak var autocompleteTableView: UITableView!
    
    var productArray: [RCHSearchProduct] = []
    var autocompleteArray: [String] = []
    var searchTerm = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.navigationBar.isHidden = true
    }
    
    func setupView() {
        searchBar.delegate = self
        searchResultsCollectionView.isHidden = true
        searchResultsCollectionView.delegate = self
        searchResultsCollectionView.dataSource = self
        
        autocompleteTableView.isHidden = true
        autocompleteTableView.delegate = self
        autocompleteTableView.dataSource = self
        
        let footerViewFrame = CGRect(x: 0, y: 0, width: autocompleteTableView.frame.width, height: autocompleteTableView.frame.height)
        let footerView = UIView(frame: footerViewFrame)
        footerView.backgroundColor = UIColor.clear
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RCHSearchViewController.handleTapOnFooter))
        tapRecognizer.numberOfTapsRequired = 1
        footerView.addGestureRecognizer(tapRecognizer)
        autocompleteTableView.tableFooterView = footerView
        
        searchResultsCollectionView!.register(UINib(nibName: "RCHProductCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: reuseIdentifier)
        
        // Temp: Config API for usable API key
        
        guard let currentUserID = UserDefaults.standard.string(forKey: kRCHUserDefaultKeyCurrentUser) else {
            fatalError()
            return
        }
        
        let config = RCHAPIClientConfig(apiKey: "showcaseparent", apiClientKey: "199c81c05e473265", endpoint: RCHEndpointProduction, useHTTPS: false)
        config.apiClientSecret = "r5j50mlag06593401nd4kt734i"
        config.userID = currentUserID
        config.sessionID = UUID().uuidString
        
        RCHSDK.defaultClient().configure(config)

    }
    
    @IBAction func handleTapOnFooter(sender: UITapGestureRecognizer) {
        resetSearch()
    }
    
    // MARK: Search

    func searchForProducts(withTerm searchText: String) {
        let placement: RCHRequestPlacement = RCHRequestPlacement.init(pageType: .search, name: "find")
        let searchBuilder: RCHSearchBuilder = RCHSDK.builder(forSearch: placement, withQuery: searchText)
        
        RCHSDK.defaultClient().sendRequest(searchBuilder.build(), success: { (responseObject) in
            
            guard let searchResult = responseObject as? RCHSearchResult else {
                return
            }
            
            self.productArray = searchResult.products!
            
            if self.productArray.count == 0 {
                self.showNoResults()
            } else {
                self.searchResultsCollectionView.reloadData()
                self.searchResultsCollectionView.isHidden = false
            }
        }) { (responseObject, error) in
            print(error)
        }
    }
    
    func resetSearch() {
        view.endEditing(true)
        autocompleteArray = []
        autocompleteTableView.reloadData()
        autocompleteTableView.isHidden = true
        searchProductsView.isHidden = false
        if productArray.isEmpty {
            showNoResults()
        }
    }
    
    func showNoResults() {
        searchResultsCollectionView.isHidden = true
        searchProductsView.isHidden = false
        searchProductsLabel.text = "No Results"
        searchProductsImageView.image = UIImage(named: "icn-tabbar-shop.pdf")
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchProductsView.isHidden = true
        autocompleteTableView.isHidden = false
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchTerm = searchBar.text else {
            print("Error: no search term entered")
            return
        }
        searchForProducts(withTerm: searchTerm)
        resetSearch()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text == "" {
            productArray = []
            autocompleteArray = []
            autocompleteTableView.reloadData()
            searchResultsCollectionView.reloadData()
        } else {
            
            autocompleteTableView.isHidden = false
            searchTerm = searchText
            searchForProducts(withTerm: searchText)
            print(searchText)
            
            // Autocomplete
            
            let autocompleteBuilder: RCHAutocompleteBuilder = RCHSDK.builderForAutocomplete(withQuery: searchText)
            
            RCHSDK.defaultClient().sendRequest(autocompleteBuilder.build(), success: { (responseObject) in
                
                guard let autocompleteSuggestions = responseObject as? [RCHAutocompleteSuggestion] else {
                    print("Result Error")
                    return
                }
                
                self.autocompleteArray = autocompleteSuggestions.map({$0.text!})
                self.autocompleteTableView.reloadData()
            }) { (responseObject, error) in
                print(error)
            }
        }
    }
 
    // MARK: UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return productArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! RCHProductCollectionViewCell
        let product = productArray[indexPath.row]
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        let priceCentsToDollars = (product.priceCents?.intValue)! / 100 as NSNumber
        
        cell.priceLabel.text = numberFormatter.string(from: priceCentsToDollars)
        cell.productImage.sd_setImage(with: URL(string: product.imageURL!))
        cell.brandLabel.text = product.brand?.uppercased()
        cell.titleLabel.text = product.name
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        performSegue(withIdentifier: "productDetailSegue", sender: self)
    }
    
    // MARK: UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return autocompleteArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "autocompleteCell", for: indexPath)
        
        let autocompleteString = autocompleteArray[indexPath.row]

        if !searchTerm.isEmpty && autocompleteArray.count > 0 {
                let searchString = searchTerm.lowercased()
                let highlightColor = UIColor(red: 0, green: 121/255, blue: 253/255, alpha: 1)
                let blueAttribute = [NSBackgroundColorAttributeName : highlightColor]
                let attributedString = NSMutableAttributedString(string: autocompleteString)
            
                let range: Range<String.Index> = autocompleteString.range(of: searchString)!
                let index: Int = autocompleteString.distance(from: autocompleteString.startIndex, to: range.lowerBound)
                let nsRange = NSMakeRange(index, searchString.characters.count)
                attributedString.addAttributes(blueAttribute, range: nsRange)

                cell.textLabel?.attributedText = attributedString
    
        } else {
            cell.textLabel?.text = autocompleteString
        }
        
        let blurEffect = UIBlurEffect(style: .light)
        let effectView = UIVisualEffectView(effect: blurEffect)
        cell.backgroundView = effectView
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedSearchTerm = autocompleteArray[indexPath.row]
        searchForProducts(withTerm: selectedSearchTerm)
        searchBar.text = selectedSearchTerm
        resetSearch()
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "productDetailSegue" {
            if let destinationViewControler = segue.destination as? RCHProductDetailViewController {
                guard let selectedIndexPath = searchResultsCollectionView.indexPathsForSelectedItems else {
                    return
                }
                let selectedProduct = productArray[selectedIndexPath[0].row]
                destinationViewControler.product = selectedProduct
            }
        }
    }
}
