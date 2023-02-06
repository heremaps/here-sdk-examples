/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

import UIKit

// A helper class to show selectable entries.
// Entries can be deleted by swiping an entry to the left.
class MenuViewController: UIViewController {
    
    // A menu entry consists of a key and the text to show.
    public var entryKeys: [String] = []
    public var entryText: [String] = []
    
    @IBOutlet var table: UITableView!

    // A listener to notify when an entry of the list is selected.
    private var escapedSelectedIndexListener: (_ index: Int) -> Void = { _ in }
    
    // A listener to notify when an entry of the list is deleted.
    private var escapedDeletedIndexListener: (_ index: Int) -> Void = { _ in }
    
    public func setSelectedIndexListener(listener: @escaping (_ index: Int) -> Void) {
        escapedSelectedIndexListener = listener
    }
    
    public func setDeletedIndexListener(listener: @escaping (_ index: Int) -> Void) {
        escapedDeletedIndexListener = listener
    }
    
    private func setSelectedIndex(_ index: Int) {
        escapedSelectedIndexListener(index)
    }
    
    private func setDeletedIndex(_ index: Int) {
        escapedDeletedIndexListener(index)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        table.delegate = self
        table.dataSource = self
    }
}

extension MenuViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entryKeys.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuEntry", for: indexPath)
        cell.textLabel?.text = entryText[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        UserDefaults.standard.removeObject(forKey: entryKeys[indexPath.row])
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
                   
            // Notfies listener on deleted index of entry.
            setDeletedIndex(indexPath.row)
            
            // Update content.
            entryKeys.remove(at: indexPath.row)
            entryText.remove(at: indexPath.row)
            
            // Update menu UI.
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.endUpdates()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
     
        // Notfies listener on selected index of entry.
        setSelectedIndex(indexPath.row)
    }
}
