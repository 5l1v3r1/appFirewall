//
//  LogViewController.swift
//  appFirewall
//
//  Copyright © 2019 Doug Leith. All rights reserved.
//

import Cocoa

class LogViewController: appViewController {
	
	@IBOutlet weak var tableView: NSTableView?
	@IBOutlet weak var searchField: NSSearchField?
	@IBOutlet weak var showBlockedButton: NSButton?
	var show_blocked: Int = 3

	@IBOutlet weak var tableHeader: NSTableHeaderView?

	@IBOutlet weak var ConnsColumn: NSTableColumn?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.tab = 1
		self.ascKey = "log_asc"
		self.sortKeys = ["time","conn"]

		tableView!.delegate = self // force using ! since shouldn't fail
		appViewDidLoad(tableView: tableView!)
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		appViewWillAppear()
	
		show_blocked = UserDefaults.standard.integer(forKey: "log_show_blocked")
		if (show_blocked == 0) {
			showBlockedButton?.state = .off
		} else {
			showBlockedButton?.state = .on
		}
		
		ConnsColumn?.headerCell.title="Connections ("+String(Int(get_num_conns_blocked()))+" blocked)"
	}
	
	@objc override func refresh(timer:Timer?) {
		// might happen if timer fires before/after view is loaded
		if (!isViewLoaded) { return }
		
 		var force : Bool = true
		if (timer != nil) {
			force = false
		}
		guard let rect = tableView?.visibleRect else {print("WARNING: problem in logView getting visible rect"); return}
		guard let firstVisibleRow = tableView?.rows(in: rect).location else {print("WARNING: problem in logView getting first visible row"); return}
		//print("refresh ",firstVisibleRow," ",has_log_changed() )
		if (force || (has_log_changed() == 2) // force or log cleared
			  || ((firstVisibleRow==0) && (has_log_changed() != 0)) ) {
			saveSelected() // save set of currently selected rows
			clear_log_changed()
			filter_log_list(Int32(show_blocked),searchField?.stringValue)
			tableView?.reloadData()
			restorePopover() //redraw getInfo popover if needed
		} else if (has_log_changed() == 1){
			// update scrollbars but leave rest of view alone.
			// shouldn't be used with view-based tables, see
			// https://developer.apple.com/documentation/appkit/nstableview/1534147-notenumberofrowschanged
			//tableView.noteNumberOfRowsChanged()
		}
		ConnsColumn?.headerCell.title="Connections ("+String(Int(get_num_conns_blocked()))+" blocked)"	
	}
	
	@IBAction func helpButton(_ sender: helpButton?) {
			sender?.clickButton(msg:"This window logs the network connections made by the apps running on your computer.  Connections marked in green are not blocked.  Those marked in red are blocked by the blacklist (on the next tab), those in orange and brown are blocked by filter files (see preferences to modify these).  The numbers in brackets indicate multiple connections within a short time.  For some connections the app name may be marked as <not found>.  These are usually connections which are so brief (a millisecond or two) that we didn't manage to link the connection to an app before the app finished.  If you'd like to catch such connections try disabling SIP (System Integrity Protection) so that the firewall can use Dtrace - this requires a reboot but lets the firewall detect link connections to apps *much* more quickly.")
	}
		
	@IBAction func showBlockedTick(_ sender: NSButton?) {
		if (sender?.state == .on) {
			show_blocked = 3
		} else {
			show_blocked = 0
		}
		UserDefaults.standard.set(show_blocked, forKey: "log_show_blocked")
		refresh(timer:nil)
	}
	
	@IBAction func searchFieldChanged(_ sender: NSSearchField) {
		//print("search: ",sender.stringValue)
		refresh(timer:nil)
	}
	
	override func numTableRows()->Int {return Int(get_filter_log_size())}
}

extension LogViewController: NSTableViewDelegate {
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		// we display log in reverse order, i.e. youngest first
		let r = mapRow(row: row)
		if (r<0) { return nil }
		let item_ptr = get_filter_log_row(Int32(r))
		guard var item = item_ptr?.pointee else {print("WARNING: problem in logView getting item_ptr"); return nil}
		let time_str = String(cString: &item.time_str.0)
		let log_line = String(cString: &item.log_line.0)
		let blocked_log = Int(item.blocked)
		let hashStr = String(cString:filtered_log_hash(item_ptr));

		let tip = getTip(ip: String(cString:get_filter_log_addr_name(Int32(r))), domain: String(cString: &item.bl_item.domain.0), name: String(cString: &item.bl_item.name.0), port: String(Int(item.raw.dport)), blocked_log: blocked_log, domains: String(cString:get_dns_count_str(item.raw.af, item.raw.dst_addr)))

		var cellIdentifier: String = ""
		var content: String = ""
		if tableColumn == tableView.tableColumns[0] {
			cellIdentifier = "TimeCell"
			content=time_str
		} else if tableColumn == tableView.tableColumns[1] {
			cellIdentifier = "ConnCell"
			content=log_line
		} else {
			cellIdentifier = "ButtonCell"
		}
		
		let cellId = NSUserInterfaceItemIdentifier(rawValue: cellIdentifier)
		if (cellIdentifier == "ButtonCell") {
			guard let cell = tableView.makeView(withIdentifier: cellId, owner: self) as? blButton else {print("WARNING: problem in logView making button cell"); return nil}
			// maintain state for button
			let log_line = String(cString: &item.log_line.0)
			cell.udp = log_line.contains("QUIC")
			cell.bl_item = item.bl_item
			cell.hashStr = hashStr;
			// restore selected state of this row
			restoreSelected(row: row, hashStr: cell.hashStr)
			// set tool tip and title
			cell.tip = tip;
			cell.updateButton()
			cell.action = #selector(BlockBtnAction)
			return cell
		}
		guard let cell = tableView.makeView(withIdentifier: cellId, owner: self) 	as? NSTableCellView else {print("WARNING: problem in logView getting making non-button cell"); return nil}
		cell.textField?.stringValue = content
		cell.textField?.toolTip = tip
		setColor(cell: cell, udp: false, white: 0, blocked: blocked_log)
		return cell
	}
	

}
