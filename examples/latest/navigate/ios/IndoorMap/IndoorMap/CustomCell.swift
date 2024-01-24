//
//  CustomCell.swift
//  IndoorMap
//
//  Created by Karmveer Kumar on 10/08/23.
//  Copyright © 2023 HERE. All rights reserved.
//

import UIKit

class CustomCell: UITableViewCell {

    @IBOutlet weak var DataView: UIView!
    @IBOutlet weak var venueLbl: UILabel!
    //@IBOutlet weak var indoor: UIImageView!
    @IBOutlet weak var indoor: UIImageView!
    @IBOutlet weak var rightaccessory: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        venueLbl.numberOfLines = 0
        venueLbl.lineBreakMode = .byWordWrapping
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
