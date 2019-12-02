//
//  WhileListViewController.swift
//  appFirewall
//
//  Copyright © 2019 Doug Leith. All rights reserved.
//

import Cocoa

class WhiteListViewController: NSViewController {

	var asc: Bool = true
	@IBOutlet weak var tableView: NSTableView!
	
	override func viewDidLoad() {
			super.viewDidLoad()
			// Do view setup here.
			tableView.delegate = self
			tableView.dataSource = self
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		self.view.window?.setFrameUsingName("connsView") // restore to previous size
		UserDefaults.standard.set(3, forKey: "tab_index") // record active tab
		// enable click of column header to call sortDescriptorsDidChange action below
		asc = UserDefaults.standard.bool(forKey: "whitelist_asc")
		if (tableView.tableColumns[0].sortDescriptorPrototype==nil) {
			tableView.tableColumns[0].sortDescriptorPrototype = NSSortDescriptor(key:"app_name",ascending:asc)
			tableView.tableColumns[1].sortDescriptorPrototype = NSSortDescriptor(key:"domain",ascending:asc)
		}
		tableView.reloadData()
	}
	
	override func viewWillDisappear() {
		// window is closing, save state
		super.viewWillDisappear()
		save_log()
		save_blocklist(); save_whitelist()
		save_dns_cache(); save_dns_conn_list()
		self.view.window?.saveFrame(usingName: "connsView") // record size of window
	}
	
	
	@IBAction func helpButton(_ sender: helpButton!) {
		sender.clickButton(msg:"Domains/apps added here will never be blocked.  Use this list when, for example, a connection is mistakenly blocked.")
	}
	
	@IBAction func click(_ sender: NSButton!) {
		BlockBtnAction(sender: sender)
	}
	
	@objc func BlockBtnAction(sender : NSButton!) {
		let row = sender.tag;
		let item = get_whitelist_item(Int32(row))
		del_whiteitem(item)
		tableView.reloadData() // update the GUI to show the change
	}
}

extension WhiteListViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return Int(get_whitelist_size())
	}
	
	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		var asc1: Int = 1
		guard let sortDescriptor = tableView.sortDescriptors.first else {
    return }
    asc = sortDescriptor.ascending
		UserDefaults.standard.set(asc, forKey: "whitelist_asc")
		if (!asc) {
			asc1 = -1
		}
		if (sortDescriptor.key == "app_name") {
			sort_white_list(Int32(asc1), 0)
		} else {
			sort_white_list(Int32(asc1), 1)
		}
		tableView.reloadData()
	}
	
}

extension WhiteListViewController: NSTableViewDelegate {

	func getRowText(row: Int) -> String {
		let item = get_whitelist_item(Int32(row))
		let name = String(cString: get_whitelist_item_name(item))
		let addr_name = String(cString: get_whitelist_item_domain(item))
		return name+", "+addr_name
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		var cellIdentifier: String = ""
		var content: String = ""
		
		let item = get_whitelist_item(Int32(row))
		let name = String(cString: get_whitelist_item_name(item))
		let domain = String(cString: get_whitelist_item_domain(item))
		
		if tableColumn == tableView.tableColumns[0] {
			cellIdentifier = "ProcessCell"
			content=name
		} else if tableColumn == tableView.tableColumns[1] {
			cellIdentifier = "ConnCell"
			content=domain
		} else if tableColumn == tableView.tableColumns[2] {
			cellIdentifier = "ButtonCell"
		}
		
		let cellId = NSUserInterfaceItemIdentifier(rawValue: cellIdentifier)
		if (cellIdentifier == "ButtonCell") {
			guard let cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSButton else {return nil}
			cell.title = "Remove"
			cell.tag = row
			cell.action = #selector(self.BlockBtnAction)
			cell.toolTip = "Remove from white list"
			return cell
		}
		guard let cell = tableView.makeView(withIdentifier: cellId, owner: self) 	as? NSTableCellView else {return nil}
		cell.textField?.stringValue = content
		return cell	}
	
	func copy(sender: AnyObject?){
		let indexSet = tableView.selectedRowIndexes
		var text = ""
		for row in indexSet {
			text += getRowText(row: row)+"\n"
		}
		let pasteBoard = NSPasteboard.general
		pasteBoard.clearContents()
		pasteBoard.setString(text, forType:NSPasteboard.PasteboardType.string)
	}
	
	func selectall(sender: AnyObject?){
		tableView.selectAll(nil)
	}
}
