/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

struct MenuItem {
    let title: String
    let onSelect: (Any) -> Void
}

struct MenuSection {
    let title: String
    let items: [MenuItem]
}

// A helper class to show a menu.
class MenuViewController: UIViewController {

    var menuSections: [MenuSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

extension MenuViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return menuSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section >= 0, section < menuSections.count else {
            return 0
        }

        return menuSections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuItem", for: indexPath)

        let section = indexPath.section
        guard section >= 0, section < menuSections.count else {
            return cell
        }

        let row = indexPath.row
        guard row >= 0, row < menuSections[section].items.count else {
            return cell
        }

        cell.textLabel?.text = menuSections[section].items[row].title
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section >= 0, section < menuSections.count else {
            return nil
        }

        return menuSections[section].title
    }
}

extension MenuViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = indexPath.section
        guard section >= 0, section < menuSections.count else {
            dismiss(animated: true, completion: nil)
            return
        }

        let row = indexPath.row
        guard row >= 0, row < menuSections[section].items.count else {
            dismiss(animated: true, completion: nil)
            return
        }

        menuSections[section].items[row].onSelect(self)
        dismiss(animated: true, completion: nil)
    }
}
