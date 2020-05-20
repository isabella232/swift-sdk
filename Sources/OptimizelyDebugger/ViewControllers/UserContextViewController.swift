/****************************************************************************
* Copyright 2020, Optimizely, Inc. and contributors                        *
*                                                                          *
* Licensed under the Apache License, Version 2.0 (the "License");          *
* you may not use this file except in compliance with the License.         *
* You may obtain a copy of the License at                                  *
*                                                                          *
*    http://www.apache.org/licenses/LICENSE-2.0                            *
*                                                                          *
* Unless required by applicable law or agreed to in writing, software      *
* distributed under the License is distributed on an "AS IS" BASIS,        *
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
* See the License for the specific language governing permissions and      *
* limitations under the License.                                           *
***************************************************************************/

#if os(iOS) && (DEBUG || OPT_DBG)

import UIKit

class UserContextViewController: UITableViewController {
    weak var client: OptimizelyClient?
    
    var userView: UITextView!
    
    var userContext: OptimizelyUserContext?
    var allAttributes = [String]()
    var attributes = [String]()
        
    let sectionHeaderHeight: CGFloat = 50.0
    var sections = [ContextItem]()
    
    enum ContextItem: String {
        case attributes = "Attributes"
        case forcedVariations = "Forced Variations"
        case forcedFeatures = "Forced Features"
        case userProfiles = "User Profiles"
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let keys = client?.config?.attributeKeyMap.keys {
            allAttributes = Array(keys)
        }
        
        sections = [.attributes,
                    .forcedVariations,
                    //.userProfiles,
                    .forcedFeatures]
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action,
                                                            target: self,
                                                            action: #selector(openMenu))
                        
        userView = UITextView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 40))
        userView.backgroundColor = .orange
        userView.font = .systemFont(ofSize: 18)
        userView.textAlignment = .center
        
        tableView.tableHeaderView = userView
        tableView.rowHeight = 60.0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshUserContext()
    }
    
    func refreshUserContext() {
        userContext = UserContextManager.getUserContext()
        userView.text = "UserID: \( userContext?.userId ?? "N/A")"
        refreshTableView()
    }
    
    @objc func openMenu() {
        
    }
    
    @objc func saveUserContext() {
        guard let userId = userView.text, userId.isEmpty == false
            else {
                let alert = UIAlertController(title: "Error", message: "Enter valid values and try again", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
        }
        
        _ = UserContextManager.setUserContext(OptimizelyUserContext(userId: userId, attributes: nil))
        
        refreshTableView()
    }
    
    func removeUserContext(userId: String, experimentKey: String) {
        _ = UserContextManager.setUserContext(nil)
        
        refreshTableView()
    }
            
    func refreshTableView() {
        guard let user = userContext, let attrs = user.attributes else { return }
        
        attributes = Array(attrs.keys)
        
        tableView.reloadData()
    }
}

// MARK: - Table view data source

extension UserContextViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let userContext = userContext else { return 0 }
        
        switch sections[section] {
        case .attributes: return userContext.attributes?.count ?? 0
        case .userProfiles: return userContext.userProfiles?.count ?? 0
        case .forcedVariations: return userContext.forcedVariations?.count ?? 0
        case .forcedFeatures: return userContext.forcedFeatures?.count ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionHeaderHeight
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let title = sections[section].rawValue
        
        let height = sectionHeaderHeight
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: height))
        
        let label = UILabel(frame: CGRect(x: 10, y: 5, width: 200.0, height: sectionHeaderHeight - 10))
        view.addSubview(label)
        label.text = title
        
        let buttonHeight: CGFloat = 40.0
        let addBtn = UIButton(type: .contactAdd)
        addBtn.frame = CGRect(x: view.frame.size.width - buttonHeight - 10.0,
                                            y: (sectionHeaderHeight - buttonHeight)/2.0,
                                            width: buttonHeight,
                                            height: buttonHeight)
        addBtn.addTarget(self, action: #selector(addItem), for: .touchUpInside)
        addBtn.tag = section
        view.addSubview(addBtn)
        
        return view
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var reuse = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier")
        if reuse == nil {
            reuse = UITableViewCell(style: .value1, reuseIdentifier: "reuseIdentifier")
        }
        let cell = reuse!

        if let (key, rawValue) = keyValueForIndexPath(indexPath) {
            var value: String?
            if let rv = rawValue {
                switch rv {
                case let rv as String:
                    value = rv
                case let rv as Int:
                    value = String(rv)
                case let rv as Bool:
                    value = String(rv)
                case let rv as Double:
                    value = String(rv)
                default:
                    value = "[Unknown]"
                }
            }
            
            cell.textLabel!.text = key
            cell.detailTextLabel!.text = value
        }
        
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let (key, rawValue) = keyValueForIndexPath(indexPath), let value = rawValue {
            openItem(sectionId: indexPath.section, keyValuePair: (key, value))
        }
        
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    func keyValueForIndexPath(_ indexPath: IndexPath) -> (String, Any?)? {
        guard let userContext = userContext else { return nil }

        var data: [String: Any?]?
        
        switch sections[indexPath.section] {
        case .attributes:
            data = userContext.attributes
        case .userProfiles:
            data = userContext.userProfiles
        case .forcedVariations:
            data = userContext.forcedVariations
        case .forcedFeatures:
            data = userContext.forcedFeatures
        }
        
        guard let dict = data else { return nil }
        
        let key = dict.keys.sorted()[indexPath.row]
        let value = dict[key] as Any?
        return (key, value)
    }
    
    @objc func addItem(sender: UIButton) {
        openItem(sectionId: sender.tag, keyValuePair: nil)
    }

    func openItem(sectionId: Int, keyValuePair: (String, Any)?) {
        guard let uc = userContext else { return }
                
        let vc: UCItemViewController
        
        let section = sections[sectionId]
        switch section {
        case .attributes:
            vc = UCAttributeViewController()
        case .userProfiles,
             .forcedVariations:
            vc = UCVariationViewController()
        case .forcedFeatures:
            vc = UCFeatureViewController()
        }
        
        vc.client = client
        vc.title = section.rawValue
        vc.pair = keyValuePair
        vc.userId = uc.userId
        
        let nvc = UINavigationController(rootViewController: vc)
     //   self.present(nvc, animated: true, completion: nil)
        self.show(vc, sender: self)
    }
}

#endif
