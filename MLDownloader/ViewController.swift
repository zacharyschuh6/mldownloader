//
//  ViewController.swift
//  MLDownloader
//
//  Created by Zac Schuh on 5/28/24.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        Task {
            await executeDownload()
        }
    }

    func executeDownload() async {
        guard let snUrl = URL.init(string: "https://github.com/alexiscreuzot/NSTDemo/blob/master/NSTDemo/StarryNight.mlmodel") else { return }
        let snToken = ""
        let snName = "StarryNight"
        
        guard var downloader = CoreMLDownloader(endpoint: snUrl, token: snToken, modelName: snName) as CoreMLDownloader? else {return}
        
        let model = try! await downloader.DownloadAndCompileModel()
    }

}

