import AppKit
import CoreImage
import Network
import UniformTypeIdentifiers
import Vision

struct CodeStudioProject: Codable {
    let content: String
    let type: String
    let foregroundRGBA: [Double]
    let backgroundRGBA: [Double]
    let scale: Double
    let margin: Double
    let correction: Int
    let savedAt: Date
    let pdf417Aspect: Double?
    let compactPDF417: Bool?
}

struct ScanRecord: Codable {
    let value: String
    let symbology: String
    let date: Date
}

struct InventoryItem: Codable {
    var sku: String
    var name: String
    var barcode: String
    var format: String
    var quantity: Int
    var minimum: Int
    var price: Double
    var location: String
    var expiration: String
    var updatedAt: Date
}

final class InventoryController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    let table = NSTableView(), search = NSSearchField(), summary = NSTextField(labelWithString: "")
    var currentBarcode: () -> (String,String)
    var items: [InventoryItem] = { guard let data = UserDefaults.standard.data(forKey:"inventoryItems"), let values = try? JSONDecoder().decode([InventoryItem].self,from:data) else { return [] }; return values }()
    var filteredIndexes: [Int] { items.indices.filter { search.stringValue.isEmpty || items[$0].sku.localizedCaseInsensitiveContains(search.stringValue) || items[$0].name.localizedCaseInsensitiveContains(search.stringValue) || items[$0].barcode.localizedCaseInsensitiveContains(search.stringValue) } }
    convenience init(currentBarcode:@escaping ()->(String,String)) { let window = NSWindow(contentRect:NSRect(x:0,y:0,width:1000,height:620),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false); window.title="Inventario CodeStudio"; window.appearance=NSAppearance(named:.darkAqua); window.center(); self.init(window:window); self.currentBarcode=currentBarcode; build() }
    override init(window:NSWindow?) { self.currentBarcode={ ("","") }; super.init(window:window) }
    required init?(coder:NSCoder) { nil }
    func build() { guard let content=window?.contentView else{return}; let stack=NSStackView(); stack.orientation = .vertical; stack.spacing=12; stack.edgeInsets=NSEdgeInsets(top:20,left:20,bottom:20,right:20); stack.translatesAutoresizingMaskIntoConstraints=false; content.addSubview(stack); NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor),stack.topAnchor.constraint(equalTo:content.topAnchor),stack.bottomAnchor.constraint(equalTo:content.bottomAnchor)]); let title=NSTextField(labelWithString:"Inventario y almacén"); title.font = .systemFont(ofSize:28,weight:.bold); stack.addArrangedSubview(title); search.placeholderString="Buscar SKU, producto o código"; search.delegate=self; stack.addArrangedSubview(search); let names=[("sku","SKU",100.0),("name","Producto",180.0),("quantity","Cantidad",75.0),("minimum","Mínimo",65.0),("price","Precio",75.0),("location","Ubicación",110.0),("expiration","Vence",90.0),("barcode","Código",190.0)]; for (id,title,width) in names { let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier(id)); column.title=title; column.width=width; table.addTableColumn(column) }; table.delegate=self; table.dataSource=self; table.usesAlternatingRowBackgroundColors=true; table.allowsMultipleSelection=true; let scroll=NSScrollView(); scroll.hasVerticalScroller=true; scroll.documentView=table; stack.addArrangedSubview(scroll); let buttons=NSStackView(views:[button("Agregar actual","plus",#selector(addCurrent)),button("Entrada +1","arrow.down.circle",#selector(stockIn)),button("Salida −1","arrow.up.circle",#selector(stockOut)),button("Eliminar","trash",#selector(deleteSelected)),button("Exportar CSV","tablecells",#selector(exportCSV))]); buttons.orientation = .horizontal; stack.addArrangedSubview(buttons); summary.textColor = .secondaryLabelColor; stack.addArrangedSubview(summary); refresh() }
    func button(_ title:String,_ symbol:String,_ action:Selector)->NSButton { let b=NSButton(title:title,target:self,action:action); b.image=NSImage(systemSymbolName:symbol,accessibilityDescription:title); b.imagePosition = .imageLeading; return b }
    func numberOfRows(in tableView:NSTableView)->Int { filteredIndexes.count }
    func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int)->NSView? { let item=items[filteredIndexes[row]], id=tableColumn?.identifier.rawValue ?? ""; let value:String; switch id { case "sku":value=item.sku; case "name":value=item.name; case "quantity":value=String(item.quantity); case "minimum":value=String(item.minimum); case "price":value=String(format:"$%.2f",item.price); case "location":value=item.location; case "expiration":value=item.expiration; default:value=item.barcode }; let text=NSTextField(labelWithString:value); if item.quantity<=item.minimum { text.textColor = .systemOrange }; return text }
    func controlTextDidChange(_ obj:Notification){ refresh() }
    func persist(){ if let data=try? JSONEncoder().encode(items){UserDefaults.standard.set(data,forKey:"inventoryItems")}; refresh() }
    func refresh(){ table.reloadData(); let low=items.filter{$0.quantity<=$0.minimum}.count, total=items.reduce(0){$0+$1.quantity}, value=items.reduce(0.0){$0+Double($1.quantity)*$1.price}; summary.stringValue="\(items.count) productos · \(total) unidades · \(low) alertas de inventario bajo · valor $\(String(format:"%.2f",value))" }
    @objc func addCurrent(){ let current=currentBarcode(); guard !current.0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return}; let alert=NSAlert(); alert.messageText="Agregar al inventario"; let form=NSStackView(); form.orientation = .vertical; form.spacing=6; let sku=NSTextField(string:"SKU-\(items.count+1)"),name=NSTextField(string:"Producto nuevo"),quantity=NSTextField(string:"1"),minimum=NSTextField(string:"1"),price=NSTextField(string:"0.00"),location=NSTextField(string:"Almacén"),expiration=NSTextField(string:""); [("SKU",sku),("Nombre",name),("Cantidad",quantity),("Mínimo",minimum),("Precio",price),("Ubicación",location),("Vence YYYY-MM-DD",expiration)].forEach{title,field in let row=NSStackView(views:[NSTextField(labelWithString:title),field]); row.orientation = .horizontal; field.widthAnchor.constraint(equalToConstant:180).isActive=true; form.addArrangedSubview(row)}; form.frame=NSRect(x:0,y:0,width:350,height:220); alert.accessoryView=form; alert.addButton(withTitle:"Agregar"); alert.addButton(withTitle:"Cancelar"); guard alert.runModal() == .alertFirstButtonReturn else{return}; let item=InventoryItem(sku:sku.stringValue,name:name.stringValue,barcode:current.0,format:current.1,quantity:Int(quantity.stringValue) ?? 0,minimum:Int(minimum.stringValue) ?? 0,price:Double(price.stringValue) ?? 0,location:location.stringValue,expiration:expiration.stringValue,updatedAt:Date()); if let index=items.firstIndex(where:{$0.sku==item.sku}){items[index].quantity += item.quantity; items[index].updatedAt=Date()}else{items.append(item)}; persist() }
    func selectedItemIndexes()->[Int]{ table.selectedRowIndexes.compactMap{row in row<filteredIndexes.count ? filteredIndexes[row]:nil} }
    @objc func stockIn(){for i in selectedItemIndexes(){items[i].quantity += 1;items[i].updatedAt=Date()};persist()}
    @objc func stockOut(){for i in selectedItemIndexes(){items[i].quantity=max(0,items[i].quantity-1);items[i].updatedAt=Date()};persist()}
    @objc func deleteSelected(){for i in selectedItemIndexes().sorted(by:>){items.remove(at:i)};persist()}
    @objc func exportCSV(){let header="sku,nombre,codigo,formato,cantidad,minimo,precio,ubicacion,vencimiento\n";let rows=items.map{"\($0.sku),\"\($0.name.replacingOccurrences(of:"\"",with:"\"\""))\",\($0.barcode),\($0.format),\($0.quantity),\($0.minimum),\($0.price),\($0.location),\($0.expiration)"}.joined(separator:"\n");let panel=NSSavePanel();panel.allowedContentTypes=[.commaSeparatedText];panel.nameFieldStringValue="inventario-codestudio.csv";guard panel.runModal() == .OK,let url=panel.url else{return};try?(header+rows).data(using:.utf8)?.write(to:url)}
}

struct BarcodeCatalogItem {
    let category: String
    let name: String
    let generatorName: String?
}

final class FormatCatalogController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    let search = NSSearchField(), category = NSPopUpButton(), table = NSTableView(), status = NSTextField(labelWithString: "")
    var onSelect: ((String) -> Void)?
    let items: [BarcodeCatalogItem] = [
        .init(category:"Lineales",name:"Code 11",generatorName:nil), .init(category:"Lineales",name:"Code 2 of 5 Interleaved",generatorName:"ITF-14"), .init(category:"Lineales",name:"Code 39",generatorName:"Code 39"), .init(category:"Lineales",name:"Code 39 Full ASCII",generatorName:nil), .init(category:"Lineales",name:"Code 93",generatorName:nil), .init(category:"Lineales",name:"Code 128",generatorName:"Code 128"), .init(category:"Lineales",name:"MSI Plessey",generatorName:nil), .init(category:"Lineales",name:"Telepen",generatorName:nil), .init(category:"Lineales",name:"Pharmacode",generatorName:nil),
        .init(category:"EAN / UPC",name:"EAN-8",generatorName:"EAN-8"), .init(category:"EAN / UPC",name:"EAN-13",generatorName:"EAN-13"), .init(category:"EAN / UPC",name:"EAN-14",generatorName:"ITF-14"), .init(category:"EAN / UPC",name:"UPC-A",generatorName:"UPC-A"), .init(category:"EAN / UPC",name:"UPC-E",generatorName:nil), .init(category:"EAN / UPC",name:"ISBN-13",generatorName:"EAN-13"), .init(category:"EAN / UPC",name:"ISMN",generatorName:nil), .init(category:"EAN / UPC",name:"ISSN",generatorName:nil),
        .init(category:"GS1 DataBar",name:"GS1 DataBar",generatorName:nil), .init(category:"GS1 DataBar",name:"GS1 DataBar Stacked",generatorName:nil), .init(category:"GS1 DataBar",name:"GS1 DataBar Stacked Omni",generatorName:nil), .init(category:"GS1 DataBar",name:"GS1 DataBar Limited",generatorName:nil), .init(category:"GS1 DataBar",name:"GS1 DataBar Expanded",generatorName:nil), .init(category:"GS1 DataBar",name:"GS1 DataBar Expanded Stacked",generatorName:nil), .init(category:"GS1 DataBar",name:"GS1-128 Composite",generatorName:nil),
        .init(category:"2D",name:"Código QR",generatorName:"Código QR"), .init(category:"2D",name:"Data Matrix",generatorName:nil), .init(category:"2D",name:"Aztec",generatorName:"Aztec"), .init(category:"2D",name:"Codablock-F",generatorName:nil), .init(category:"2D",name:"MaxiCode",generatorName:nil), .init(category:"2D",name:"MicroPDF417",generatorName:nil), .init(category:"2D",name:"PDF417",generatorName:"PDF417"), .init(category:"2D",name:"Micro QR",generatorName:nil), .init(category:"2D",name:"Han Xin",generatorName:nil), .init(category:"2D",name:"DotCode",generatorName:nil),
        .init(category:"GS1 2D",name:"GS1 QR Code",generatorName:"Código QR"), .init(category:"GS1 2D",name:"GS1 Data Matrix",generatorName:nil), .init(category:"GS1 2D",name:"GS1 Digital Link QR",generatorName:"Código QR"), .init(category:"GS1 2D",name:"GS1 Digital Link Data Matrix",generatorName:nil),
        .init(category:"Postales",name:"Australia Post",generatorName:nil), .init(category:"Postales",name:"DAFT",generatorName:nil), .init(category:"Postales",name:"DPD Barcode",generatorName:nil), .init(category:"Postales",name:"Japanese Postal",generatorName:nil), .init(category:"Postales",name:"KIX",generatorName:nil), .init(category:"Postales",name:"Korean Postal",generatorName:nil), .init(category:"Postales",name:"Royal Mail 4-State",generatorName:nil), .init(category:"Postales",name:"USPS PostNet",generatorName:nil), .init(category:"Postales",name:"USPS IM Package",generatorName:nil), .init(category:"Postales",name:"UPU S10",generatorName:nil),
        .init(category:"Pagos",name:"EPC QR",generatorName:"Código QR"), .init(category:"Pagos",name:"Swiss QR",generatorName:"Código QR"), .init(category:"Pagos",name:"ZATCA QR",generatorName:"Código QR"),
        .init(category:"Salud",name:"Code 32",generatorName:nil), .init(category:"Salud",name:"HIBC Code 128",generatorName:"Code 128"), .init(category:"Salud",name:"HIBC Code 39",generatorName:"Code 39"), .init(category:"Salud",name:"HIBC Aztec",generatorName:"Aztec"), .init(category:"Salud",name:"HIBC PDF417",generatorName:"PDF417"), .init(category:"Salud",name:"HIBC QR",generatorName:"Código QR"), .init(category:"Salud",name:"NTIN",generatorName:nil), .init(category:"Salud",name:"PPN",generatorName:nil), .init(category:"Salud",name:"PZN",generatorName:nil),
        .init(category:"Plantillas",name:"Wi-Fi",generatorName:"Código QR"), .init(category:"Plantillas",name:"vCard",generatorName:"Código QR"), .init(category:"Plantillas",name:"Evento",generatorName:"Código QR"), .init(category:"Plantillas",name:"Enlace web",generatorName:"Código QR"), .init(category:"Plantillas",name:"SMS",generatorName:"Código QR"), .init(category:"Plantillas",name:"Teléfono",generatorName:"Código QR")
    ]
    var filtered: [BarcodeCatalogItem] { items.filter { (category.titleOfSelectedItem == "Todas" || $0.category == category.titleOfSelectedItem) && (search.stringValue.isEmpty || $0.name.localizedCaseInsensitiveContains(search.stringValue)) } }

    convenience init(onSelect: @escaping (String) -> Void) {
        let window = NSWindow(contentRect: NSRect(x:0,y:0,width:720,height:620), styleMask:[.titled,.closable,.resizable], backing:.buffered, defer:false); window.title = "Catálogo de formatos"; window.appearance = NSAppearance(named:.darkAqua); window.center(); self.init(window:window); self.onSelect = onSelect; build()
    }
    func build() {
        guard let content = window?.contentView else { return }; let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 12; stack.edgeInsets = NSEdgeInsets(top:20,left:20,bottom:20,right:20); stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack); NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor),stack.topAnchor.constraint(equalTo:content.topAnchor),stack.bottomAnchor.constraint(equalTo:content.bottomAnchor)])
        let title = NSTextField(labelWithString:"Catálogo profesional"); title.font = .systemFont(ofSize:28,weight:.bold); stack.addArrangedSubview(title); let help = NSTextField(labelWithString:"Busca por nombre o filtra por familia. Doble clic para usar un generador disponible."); help.textColor = .secondaryLabelColor; stack.addArrangedSubview(help)
        category.addItems(withTitles:["Todas"] + Array(Set(items.map(\.category))).sorted()); category.target = self; category.action = #selector(reload); search.placeholderString = "Buscar formato"; search.delegate = self; let filters = NSStackView(views:[search,category]); filters.orientation = .horizontal; filters.distribution = .fillEqually; stack.addArrangedSubview(filters)
        let column = NSTableColumn(identifier:NSUserInterfaceItemIdentifier("format")); column.title = "Formato"; table.addTableColumn(column); table.headerView = nil; table.delegate = self; table.dataSource = self; table.target = self; table.doubleAction = #selector(selectFormat); table.rowHeight = 34; let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = table; stack.addArrangedSubview(scroll); status.textColor = .secondaryLabelColor; stack.addArrangedSubview(status)
    }
    func numberOfRows(in tableView:NSTableView)->Int { filtered.count }
    func tableView(_ tableView:NSTableView, viewFor tableColumn:NSTableColumn?, row:Int)->NSView? { let item = filtered[row]; let cell = NSTableCellView(); let text = NSTextField(labelWithString:"\(item.generatorName == nil ? "◉ SOLO ESCANEAR" : "◆ GENERAR")    \(item.name)    · \(item.category)"); text.textColor = item.generatorName == nil ? .secondaryLabelColor : NSColor(calibratedRed:0.70,green:0.63,blue:1,alpha:1); text.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(text); NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo:cell.leadingAnchor,constant:8),text.centerYAnchor.constraint(equalTo:cell.centerYAnchor)]); return cell }
    @objc func reload() { table.reloadData() }
    func controlTextDidChange(_ obj:Notification) { reload() }
    @objc func selectFormat() { guard table.selectedRow >= 0 else { return }; let item = filtered[table.selectedRow]; guard let generator = item.generatorName else { status.stringValue = "\(item.name) está disponible para reconocimiento con Apple Vision, pero todavía no para generación."; return }; onSelect?(generator); status.stringValue = "Formato seleccionado: \(item.name)"; window?.close() }
}

final class DropTextView: NSTextView {
    var changed: (() -> Void)?
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); registerForDraggedTypes([.fileURL, .string]) }
    override init(frame: NSRect, textContainer: NSTextContainer?) { super.init(frame: frame, textContainer: textContainer); registerForDraggedTypes([.fileURL, .string]) }
    required init?(coder: NSCoder) { super.init(coder: coder); registerForDraggedTypes([.fileURL, .string]) }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let board = sender.draggingPasteboard
        if let raw = board.string(forType: .fileURL), let url = URL(string: raw), let value = try? String(contentsOf: url, encoding: .utf8) { string = value; changed?(); return true }
        if let value = board.string(forType: .string) { string = value; changed?(); return true }
        return false
    }
}

final class LabelSheet: NSView {
    let image: NSImage
    init(_ image: NSImage) { self.image = image; super.init(frame: NSRect(x: 0, y: 0, width: 612, height: 792)) }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        for row in 0..<5 { for column in 0..<2 {
            let rect = NSRect(x: 28 + CGFloat(column) * 284, y: 28 + CGFloat(row) * 150, width: 272, height: 138)
            image.draw(in: rect.insetBy(dx: 12, dy: 12), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.none])
            NSColor.separatorColor.setStroke(); NSBezierPath(rect: rect).stroke()
        }}
    }
}

final class StudioSkinView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let colors = [NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.12, alpha: 1), NSColor(calibratedRed: 0.09, green: 0.055, blue: 0.16, alpha: 1), NSColor(calibratedRed: 0.035, green: 0.10, blue: 0.15, alpha: 1)]
        NSGradient(colors: colors)?.draw(in: bounds, angle: -22)
        let glow = NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 430, y: bounds.maxY - 330, width: 560, height: 560))
        NSColor(calibratedRed: 0.38, green: 0.20, blue: 0.95, alpha: 0.10).setFill(); glow.fill()
    }
}

final class PhoneTransferServer {
    private var listener: NWListener?
    private var expiration: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.anthony.pdf417creator.transfer")
    private let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    private let png: Data
    private let jpg: Data
    var downloaded: ((String) -> Void)?

    init(png: Data, jpg: Data) { self.png = png; self.jpg = jpg }

    func start(completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] in self?.handle($0) }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard let port = listener.port else { return }
                    let address = Self.localIPv4() ?? ProcessInfo.processInfo.hostName
                    DispatchQueue.main.async { completion(.success(URL(string: "http://\(address):\(port)/\(self.token)")!)) }
                case .failed(let error): DispatchQueue.main.async { completion(.failure(error)) }
                default: break
                }
            }
            listener.start(queue: queue)
            let work = DispatchWorkItem { [weak self] in self?.stop() }; expiration = work
            queue.asyncAfter(deadline: .now() + 600, execute: work)
        } catch { completion(.failure(error)) }
    }

    func stop() { expiration?.cancel(); listener?.cancel(); listener = nil }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8), let first = request.components(separatedBy: "\r\n").first else { connection.cancel(); return }
            let path = first.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
            let root = "/\(self.token)"
            if path == root || path == root + "/" {
                let page = """
                <!doctype html><html lang="es"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CodeStudio</title>
                <style>body{margin:0;background:linear-gradient(145deg,#111326,#261440,#092337);color:white;font:17px -apple-system;padding:32px;text-align:center}.card{max-width:520px;margin:auto;background:#ffffff14;border:1px solid #ffffff22;border-radius:24px;padding:28px}img{max-width:100%;background:white;border-radius:16px;margin:18px 0}a{display:block;background:#7657f5;color:white;text-decoration:none;padding:15px;margin:12px;border-radius:12px;font-weight:700}.muted{color:#c9c5d8;font-size:14px}</style>
                <div class="card"><h1>◆ CodeStudio</h1><p>Tu código está listo para guardarse en el teléfono.</p><img src="\(root)/barcode.png"><a href="\(root)/barcode.png" download="codigo.png">Descargar PNG</a><a href="\(root)/barcode.jpg" download="codigo.jpg">Descargar JPG</a><p class="muted">Transferencia privada desde tu Mac · El enlace caduca automáticamente.</p></div></html>
                """
                self.respond(connection, status: "200 OK", type: "text/html; charset=utf-8", body: Data(page.utf8))
            } else if path == root + "/barcode.png" { self.respond(connection, status: "200 OK", type: "image/png", body: self.png, filename: "codigo.png"); DispatchQueue.main.async { self.downloaded?("PNG") }
            } else if path == root + "/barcode.jpg" { self.respond(connection, status: "200 OK", type: "image/jpeg", body: self.jpg, filename: "codigo.jpg"); DispatchQueue.main.async { self.downloaded?("JPG") }
            } else { self.respond(connection, status: "404 Not Found", type: "text/plain", body: Data("Enlace no válido o caducado".utf8)) }
        }
    }

    private func respond(_ connection: NWConnection, status: String, type: String, body: Data, filename: String? = nil) {
        var header = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n"
        if let filename { header += "Content-Disposition: attachment; filename=\"\(filename)\"\r\n" }
        header += "\r\n"; var response = Data(header.utf8); response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func localIPv4() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?; guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }; defer { freeifaddrs(interfaces) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee; guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET), String(cString: interface.ifa_name) == "en0" else { continue }
            var address = interface.ifa_addr.pointee; var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(&address, socklen_t(interface.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 { return String(cString: host) }
        }
        return nil
    }
}

final class BarcodeWindowController: NSWindowController, NSTextViewDelegate {
    let input = DropTextView(frame: .zero), type = NSPopUpButton(), templates = NSPopUpButton(), historyMenu = NSPopUpButton(), preview = NSImageView()
    let status = NSTextField(labelWithString: "Listo para crear."), count = NSTextField(labelWithString: "0 caracteres")
    let statistics = NSTextField(labelWithString: "0 creados · 0 verificados · 0 transferidos")
    let foreground = NSColorWell(), background = NSColorWell(), scale = NSSlider(value: 4, minValue: 2, maxValue: 10, target: nil, action: nil), margin = NSSlider(value: 24, minValue: 0, maxValue: 80, target: nil, action: nil)
    let aspect = NSSlider(value: 3, minValue: 1, maxValue: 5, target: nil, action: nil), compact = NSButton(checkboxWithTitle: "PDF417 compacto", target: nil, action: nil)
    let escapeSequences = NSButton(checkboxWithTitle: "Interpretar \\F, \\t y \\n", target: nil, action: nil), onePerLine = NSButton(checkboxWithTitle: "Un código por línea", target: nil, action: nil)
    let correction = NSPopUpButton(), live = NSButton(checkboxWithTitle: "Vista previa automática", target: nil, action: nil), generate = NSButton()
    var barcode: NSImage?, delayed: DispatchWorkItem?
    var transferServer: PhoneTransferServer?, transferPanel: NSPanel?
    var catalogController: FormatCatalogController?
    var inventoryController: InventoryController?
    var history = UserDefaults.standard.stringArray(forKey: "history") ?? [], favorites = UserDefaults.standard.stringArray(forKey: "favorites") ?? []
    var createdCount = UserDefaults.standard.integer(forKey: "createdCount"), verifiedCount = UserDefaults.standard.integer(forKey: "verifiedCount"), transferredCount = UserDefaults.standard.integer(forKey: "transferredCount")
    var scanRecords: [ScanRecord] = { guard let data = UserDefaults.standard.data(forKey: "scanRecords"), let values = try? JSONDecoder().decode([ScanRecord].self, from: data) else { return [] }; return values }()
    let ciContext = CIContext()

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "CodeStudio · Barcode Creator Pro"; window.titlebarAppearsTransparent = true; window.appearance = NSAppearance(named: .darkAqua); window.backgroundColor = .clear; window.isOpaque = false; window.contentView = StudioSkinView(); window.center(); window.minSize = NSSize(width: 980, height: 660)
        self.init(window: window); buildUI(); restoreDraft(); updateType(); updateHistory()
    }

    func buildUI() {
        guard let content = window?.contentView else { return }
        let root = NSStackView(); root.orientation = .horizontal; root.spacing = 0; root.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: content.leadingAnchor), root.trailingAnchor.constraint(equalTo: content.trailingAnchor), root.topAnchor.constraint(equalTo: content.topAnchor), root.bottomAnchor.constraint(equalTo: content.bottomAnchor)])
        root.addArrangedSubview(makeSidebar()); root.addArrangedSubview(makeEditor()); root.addArrangedSubview(makePreview())
    }

    func makeSidebar() -> NSView {
        let effect = NSVisualEffectView(); effect.material = .hudWindow; effect.blendingMode = .withinWindow; effect.state = .active; effect.wantsLayer = true; effect.layer?.backgroundColor = NSColor(calibratedWhite: 0.03, alpha: 0.48).cgColor; effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor; effect.layer?.borderWidth = 1; effect.widthAnchor.constraint(equalToConstant: 230).isActive = true
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10; stack.edgeInsets = NSEdgeInsets(top: 58, left: 18, bottom: 20, right: 18); stack.translatesAutoresizingMaskIntoConstraints = false; effect.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor), stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor), stack.topAnchor.constraint(equalTo: effect.topAnchor), stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor)])
        let brand = NSTextField(labelWithString: "◆ CodeStudio"); brand.font = .systemFont(ofSize: 24, weight: .heavy); brand.textColor = NSColor(calibratedRed: 0.68, green: 0.60, blue: 1, alpha: 1); stack.addArrangedSubview(brand)
        let sub = NSTextField(labelWithString: "BARCODE CREATOR PRO"); sub.font = .systemFont(ofSize: 9, weight: .bold); sub.textColor = .secondaryLabelColor; stack.addArrangedSubview(sub); stack.setCustomSpacing(24, after: sub)
        ["PDF417", "Código QR", "Code 128", "Aztec"].enumerated().forEach { index, title in let button = makeButton(title, index == 1 ? "qrcode" : "barcode", #selector(selectType(_:))); button.tag = index; button.alignment = .left; button.widthAnchor.constraint(equalToConstant: 194).isActive = true; stack.addArrangedSubview(button) }
        let catalog = makeButton("Catálogo completo", "square.grid.3x3", #selector(showCatalog)); catalog.alignment = .left; catalog.widthAnchor.constraint(equalToConstant: 194).isActive = true; stack.addArrangedSubview(catalog)
        let inventory = makeButton("Inventario", "shippingbox", #selector(showInventory)); inventory.alignment = .left; inventory.widthAnchor.constraint(equalToConstant:194).isActive=true; stack.addArrangedSubview(inventory)
        let separator = NSBox(); separator.boxType = .separator; separator.titlePosition = .noTitle; stack.addArrangedSubview(separator); let recent = NSTextField(labelWithString: "RECIENTES Y FAVORITOS"); recent.font = .systemFont(ofSize: 10, weight: .bold); recent.textColor = .secondaryLabelColor; stack.addArrangedSubview(recent)
        historyMenu.target = self; historyMenu.action = #selector(openHistory); historyMenu.widthAnchor.constraint(equalToConstant: 194).isActive = true; stack.addArrangedSubview(historyMenu)
        stack.addArrangedSubview(makeButton("Guardar favorito", "star", #selector(toggleFavorite))); stack.addArrangedSubview(NSView())
        let privacy = NSTextField(wrappingLabelWithString: "Privado y local\nTus datos nunca salen de esta Mac."); privacy.textColor = .secondaryLabelColor; stack.addArrangedSubview(privacy)
        return effect
    }

    func makeEditor() -> NSView {
        let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 13; stack.edgeInsets = NSEdgeInsets(top: 56, left: 24, bottom: 20, right: 24); stack.wantsLayer = true; stack.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.62).cgColor; stack.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor; stack.layer?.borderWidth = 1; stack.widthAnchor.constraint(equalToConstant: 390).isActive = true
        let title = NSTextField(labelWithString: "Crear código"); title.font = .systemFont(ofSize: 28, weight: .bold); stack.addArrangedSubview(title)
        let helper = NSTextField(wrappingLabelWithString: "Escribe, pega o arrastra texto. La vista previa se actualiza automáticamente."); helper.textColor = .secondaryLabelColor; stack.addArrangedSubview(helper)
        let projects = horizontal([makeButton("Abrir proyecto", "folder", #selector(openProject)), makeButton("Guardar proyecto", "square.and.arrow.down", #selector(saveProject))]); projects.distribution = .fillEqually; stack.addArrangedSubview(projects)
        type.addItems(withTitles: ["PDF417", "Código QR", "Code 128", "Aztec", "Code 39", "EAN-13", "EAN-8", "UPC-A", "ITF-14"]); type.target = self; type.action = #selector(typePickerChanged); stack.addArrangedSubview(type)
        templates.addItems(withTitles: ["Plantillas…", "Enlace web", "Red Wi‑Fi", "Contacto", "Evento", "Teléfono", "Correo electrónico"]); templates.target = self; templates.action = #selector(applyTemplate); stack.addArrangedSubview(horizontal([templates, makeButton("Asistente GS1", "shippingbox", #selector(gs1Assistant))]))
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.wantsLayer = true; scroll.layer?.cornerRadius = 10; scroll.layer?.borderWidth = 1; scroll.layer?.borderColor = NSColor.separatorColor.cgColor
        input.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular); input.textContainerInset = NSSize(width: 12, height: 12); input.isRichText = false; input.allowsUndo = true; input.delegate = self; input.changed = { [weak self] in self?.contentChanged() }; scroll.documentView = input; scroll.heightAnchor.constraint(equalToConstant: 190).isActive = true; stack.addArrangedSubview(scroll)
        live.state = .on; live.target = self; live.action = #selector(schedule); stack.addArrangedSubview(horizontal([count, NSView(), live]))
        escapeSequences.target = self; escapeSequences.action = #selector(schedule); onePerLine.target = self; onePerLine.action = #selector(schedule); stack.addArrangedSubview(horizontal([escapeSequences, onePerLine]))
        let custom = NSTextField(labelWithString: "PERSONALIZAR"); custom.font = .systemFont(ofSize: 10, weight: .bold); custom.textColor = .secondaryLabelColor; stack.addArrangedSubview(custom)
        foreground.color = .black; background.color = .white; [foreground, background].forEach { $0.target = self; $0.action = #selector(schedule) }; stack.addArrangedSubview(horizontal([label("Código"), foreground, label("Fondo"), background]))
        [scale, margin].forEach { $0.target = self; $0.action = #selector(schedule); $0.widthAnchor.constraint(greaterThanOrEqualToConstant: 230).isActive = true }; stack.addArrangedSubview(horizontal([label("Tamaño"), scale])); stack.addArrangedSubview(horizontal([label("Margen"), margin]))
        correction.addItems(withTitles: ["Bajo", "Medio", "Alto", "Máximo"]); correction.selectItem(at: 1); correction.target = self; correction.action = #selector(schedule); stack.addArrangedSubview(horizontal([label("Corrección"), correction]))
        generate.bezelStyle = .texturedRounded; generate.controlSize = .large; generate.contentTintColor = NSColor(calibratedRed: 0.64, green: 0.48, blue: 1, alpha: 1); generate.keyEquivalent = "\r"; generate.target = self; generate.action = #selector(generateBarcode); stack.addArrangedSubview(generate)
        let pdfAdvanced = horizontal([label("Proporción PDF417"), aspect, compact]); aspect.target = self; aspect.action = #selector(schedule); compact.target = self; compact.action = #selector(schedule); stack.addArrangedSubview(pdfAdvanced)
        let batch = horizontal([makeButton("Importar CSV", "tablecells", #selector(importCSV)), makeButton("Crear serie", "number", #selector(generateSequence)), makeButton("Etiquetas", "rectangle.grid.2x2", #selector(printLabels))]); batch.distribution = .fillEqually; stack.addArrangedSubview(batch)
        return stack
    }

    func makePreview() -> NSView {
        let effect = NSVisualEffectView(); effect.material = .hudWindow; effect.blendingMode = .withinWindow; effect.state = .active; effect.wantsLayer = true; effect.layer?.backgroundColor = NSColor(calibratedWhite: 0.025, alpha: 0.36).cgColor
        let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 16; stack.edgeInsets = NSEdgeInsets(top: 56, left: 28, bottom: 20, right: 28); stack.translatesAutoresizingMaskIntoConstraints = false; effect.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor), stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor), stack.topAnchor.constraint(equalTo: effect.topAnchor), stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor), effect.widthAnchor.constraint(greaterThanOrEqualToConstant: 480)])
        let title = NSTextField(labelWithString: "Vista previa"); title.font = .systemFont(ofSize: 28, weight: .bold); stack.addArrangedSubview(horizontal([title, NSView(), makeButton("Copiar", "doc.on.doc", #selector(copyImage))]))
        preview.imageScaling = .scaleProportionallyUpOrDown; preview.wantsLayer = true; preview.layer?.backgroundColor = NSColor(calibratedWhite: 0.98, alpha: 1).cgColor; preview.layer?.cornerRadius = 22; preview.layer?.borderWidth = 2; preview.layer?.borderColor = NSColor(calibratedRed: 0.55, green: 0.40, blue: 1, alpha: 0.35).cgColor; preview.layer?.shadowColor = NSColor.black.cgColor; preview.layer?.shadowOpacity = 0.35; preview.layer?.shadowRadius = 18; preview.layer?.shadowOffset = CGSize(width: 0, height: -6); preview.image = NSImage(systemSymbolName: "barcode.viewfinder", accessibilityDescription: "Vista previa"); stack.addArrangedSubview(preview)
        let exports = horizontal([makeButton("PNG", "photo", #selector(exportPNG)), makeButton("JPEG", "photo.fill", #selector(exportJPEG)), makeButton("PDF", "doc", #selector(exportPDF)), makeButton("SVG", "chevron.left.forwardslash.chevron.right", #selector(exportSVG)), makeButton("Imprimir", "printer", #selector(printBarcode))]); exports.distribution = .fillEqually; stack.addArrangedSubview(exports)
        let professional = horizontal([makeButton("Verificar", "checkmark.seal", #selector(verifyBarcode)), makeButton("Calidad A–F", "waveform.path.ecg", #selector(gradeQuality)), makeButton("Escanear", "viewfinder", #selector(scanImage)), makeButton("Compartir", "square.and.arrow.up", #selector(shareBarcode(_:)))]); professional.distribution = .fillEqually; stack.addArrangedSubview(professional)
        let phone = makeButton("Enviar al teléfono", "iphone.and.arrow.forward", #selector(sendToPhone)); phone.controlSize = .large; phone.contentTintColor = NSColor(calibratedRed: 0.58, green: 0.82, blue: 1, alpha: 1); stack.addArrangedSubview(phone)
        status.textColor = .secondaryLabelColor; stack.addArrangedSubview(status); statistics.font = .systemFont(ofSize: 11, weight: .medium); statistics.textColor = NSColor(calibratedRed: 0.60, green: 0.78, blue: 1, alpha: 1); stack.addArrangedSubview(statistics); updateStatistics(); return effect
    }

    func horizontal(_ views: [NSView]) -> NSStackView { let value = NSStackView(views: views); value.orientation = .horizontal; value.spacing = 8; return value }
    func label(_ value: String) -> NSTextField { let text = NSTextField(labelWithString: value); text.textColor = .secondaryLabelColor; return text }
    func makeButton(_ title: String, _ symbol: String, _ action: Selector) -> NSButton { let button = NSButton(title: title, target: self, action: action); button.bezelStyle = .rounded; button.contentTintColor = NSColor(calibratedRed: 0.70, green: 0.63, blue: 1, alpha: 1); button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title); button.imagePosition = .imageLeading; return button }
    @objc func selectType(_ sender: NSButton) { type.selectItem(at: sender.tag); updateType(); schedule() }
    @objc func showCatalog() { let controller = FormatCatalogController { [weak self] generator in guard let self else { return }; self.type.selectItem(withTitle: generator); self.updateType(); self.schedule() }; catalogController = controller; controller.showWindow(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func showInventory(){ let controller=InventoryController{[weak self] in guard let self else{return("","")};return(self.input.string.trimmingCharacters(in:.whitespacesAndNewlines),self.type.titleOfSelectedItem ?? "PDF417")}; inventoryController=controller;controller.showWindow(nil);NSApp.activate(ignoringOtherApps:true) }
    @objc func typePickerChanged() { updateType(); schedule() }
    func updateType() { let selected = type.titleOfSelectedItem ?? "PDF417"; generate.title = "Generar \(selected)"; correction.isEnabled = selected == "PDF417" || selected == "Código QR"; aspect.isEnabled = selected == "PDF417"; compact.isEnabled = selected == "PDF417"; window?.title = "CodeStudio · \(selected)" }
    func textDidChange(_ notification: Notification) { contentChanged() }
    func contentChanged() { count.stringValue = "\(input.string.count) caracteres"; saveDraft(); schedule() }
    @objc func schedule() { guard live.state == .on else { return }; delayed?.cancel(); let work = DispatchWorkItem { [weak self] in self?.generateBarcode() }; delayed = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work) }

    @objc func generateBarcode() { guard let image = render(input.string) else { barcode = nil; preview.image = NSImage(systemSymbolName: "barcode.viewfinder", accessibilityDescription: nil); return }; let changed = barcode == nil; barcode = image; preview.image = image; remember(input.string); if changed { createdCount += 1; UserDefaults.standard.set(createdCount, forKey: "createdCount"); updateStatistics() }; status.stringValue = "\(type.titleOfSelectedItem ?? "Código") generado · \(Int(image.size.width)) × \(Int(image.size.height)) px" }
    func render(_ raw: String) -> NSImage? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines); if onePerLine.state == .on { value = value.components(separatedBy: .newlines).first(where: { !$0.isEmpty }) ?? "" }; if escapeSequences.state == .on { value = value.replacingOccurrences(of: "\\F", with: String(UnicodeScalar(29))).replacingOccurrences(of: "\\t", with: "\t").replacingOccurrences(of: "\\n", with: "\n") }; guard !value.isEmpty, let data = value.data(using: .utf8) else { status.stringValue = "Escribe contenido para generar el código."; return nil }
        let selected = type.titleOfSelectedItem ?? "PDF417", names = ["Código QR":"CIQRCodeGenerator", "Code 128":"CICode128BarcodeGenerator", "Aztec":"CIAztecCodeGenerator"]
        if ["Code 39", "EAN-13", "EAN-8", "UPC-A", "ITF-14"].contains(selected) { return renderLinear(value, format: selected) }
        guard let filter = CIFilter(name: names[selected] ?? "CIPDF417BarcodeGenerator") else { return nil }; filter.setValue(data, forKey: "inputMessage")
        if selected == "Código QR" { filter.setValue(["L","M","Q","H"][correction.indexOfSelectedItem], forKey: "inputCorrectionLevel") }
        if selected == "PDF417" { filter.setValue(correction.indexOfSelectedItem + 2, forKey: "inputCorrectionLevel"); filter.setValue(aspect.doubleValue, forKey: "inputPreferredAspectRatio"); filter.setValue(compact.state == .on, forKey: "inputCompactStyle") }
        guard var output = filter.outputImage else { status.stringValue = "Contenido demasiado largo o incompatible."; return nil }
        let colors = CIFilter(name: "CIFalseColor")!; colors.setValue(output, forKey: kCIInputImageKey); colors.setValue(CIColor(color: foreground.color), forKey: "inputColor0"); colors.setValue(CIColor(color: background.color), forKey: "inputColor1"); output = colors.outputImage ?? output
        let factor = CGFloat(scale.doubleValue); output = output.transformed(by: CGAffineTransform(scaleX: factor, y: factor)); let padding = CGFloat(margin.doubleValue), extent = output.extent.insetBy(dx: -padding, dy: -padding); output = output.composited(over: CIImage(color: CIColor(color: background.color) ?? CIColor.white).cropped(to: extent))
        guard let cg = ciContext.createCGImage(output, from: extent) else { return nil }; return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    func renderLinear(_ value: String, format: String) -> NSImage? {
        let bits: String?
        switch format {
        case "Code 39": bits = code39(value.uppercased())
        case "EAN-13": bits = ean13(value)
        case "EAN-8": bits = ean8(value)
        case "UPC-A": bits = upca(value)
        case "ITF-14": bits = itf14(value)
        default: bits = nil
        }
        guard let bits else { status.stringValue = "El contenido no es válido para \(format). Revisa la longitud y los caracteres."; return nil }
        let module = max(2, Int(scale.doubleValue.rounded())), quiet = max(10, Int(margin.doubleValue)), height = 180
        let image = NSImage(size: NSSize(width: bits.count * module + quiet * 2, height: height + quiet * 2)); image.lockFocus(); background.color.setFill(); NSRect(origin: .zero, size: image.size).fill(); foreground.color.setFill()
        for (index, bit) in bits.enumerated() where bit == "1" { NSRect(x: quiet + index * module, y: quiet, width: module, height: height).fill() }
        image.unlockFocus(); return image
    }
    func code39(_ value: String) -> String? {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%*")
        let encodings = [0x034,0x121,0x061,0x160,0x031,0x130,0x070,0x025,0x124,0x064,0x109,0x049,0x148,0x019,0x118,0x058,0x00D,0x10C,0x04C,0x01C,0x103,0x043,0x142,0x013,0x112,0x052,0x007,0x106,0x046,0x016,0x181,0x0C1,0x1C0,0x091,0x190,0x0D0,0x085,0x184,0x0C4,0x0A8,0x0A2,0x08A,0x02A,0x094]
        let map = Dictionary(uniqueKeysWithValues: zip(characters, encodings)); guard value.allSatisfy({ map[$0] != nil && $0 != "*" }) else { return nil }
        var result = ""; for character in Array("*" + value + "*") { guard let encoding = map[character] else { return nil }; for index in 0..<9 { let wide = (encoding & (1 << (8 - index))) != 0, bar = index % 2 == 0; result += String(repeating: bar ? "1" : "0", count: wide ? 3 : 1) }; result += "0" }; return result
    }
    let eanL = ["0001101","0011001","0010011","0111101","0100011","0110001","0101111","0111011","0110111","0001011"]
    let eanG = ["0100111","0110011","0011011","0100001","0011101","0111001","0000101","0010001","0001001","0010111"]
    let eanR = ["1110010","1100110","1101100","1000010","1011100","1001110","1010000","1000100","1001000","1110100"]
    func checkDigit(_ digits: [Int]) -> Int { let sum = digits.reversed().enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 3 : 1) }; return (10 - sum % 10) % 10 }
    func normalizedDigits(_ value: String, body: Int, total: Int) -> [Int]? { guard value.allSatisfy(\.isNumber) else { return nil }; var digits = value.compactMap { Int(String($0)) }; if digits.count == body { digits.append(checkDigit(digits)) }; guard digits.count == total, checkDigit(Array(digits.dropLast())) == digits.last else { return nil }; return digits }
    func ean13(_ value: String) -> String? { guard let d = normalizedDigits(value, body: 12, total: 13) else { return nil }; let parity = ["LLLLLL","LLGLGG","LLGGLG","LLGGGL","LGLLGG","LGGLLG","LGGGLL","LGLGLG","LGLGGL","LGGLGL"][d[0]]; var result = "101"; for index in 1...6 { result += parity[parity.index(parity.startIndex, offsetBy: index - 1)] == "L" ? eanL[d[index]] : eanG[d[index]] }; result += "01010"; for index in 7...12 { result += eanR[d[index]] }; return result + "101" }
    func ean8(_ value: String) -> String? { guard let d = normalizedDigits(value, body: 7, total: 8) else { return nil }; return "101" + d[0...3].map { eanL[$0] }.joined() + "01010" + d[4...7].map { eanR[$0] }.joined() + "101" }
    func upca(_ value: String) -> String? { guard value.count == 11 || value.count == 12 else { return nil }; return ean13("0" + value) }
    func itf14(_ value: String) -> String? { guard let d = normalizedDigits(value, body: 13, total: 14) else { return nil }; let pattern = ["nnwwn","wnnnw","nwnnw","wwnnn","nnwnw","wnwnn","nwwnn","nnnww","wnnwn","nwnwn"]; var result = "1010"; for pair in stride(from: 0, to: 14, by: 2) { let bars = pattern[d[pair]], spaces = pattern[d[pair + 1]]; for index in 0..<5 { let b = bars[bars.index(bars.startIndex, offsetBy: index)] == "w" ? 3 : 1, s = spaces[spaces.index(spaces.startIndex, offsetBy: index)] == "w" ? 3 : 1; result += String(repeating: "1", count: b) + String(repeating: "0", count: s) } }; return result + "11101" }

    func remember(_ raw: String) { let value = raw.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }; history.removeAll { $0 == value }; history.insert(value, at: 0); history = Array(history.prefix(20)); UserDefaults.standard.set(history, forKey: "history"); updateHistory() }
    func updateHistory() { historyMenu.removeAllItems(); historyMenu.addItem(withTitle: "Abrir reciente…"); favorites.forEach { historyMenu.addItem(withTitle: "★ " + String($0.prefix(28))) }; history.filter { !favorites.contains($0) }.forEach { historyMenu.addItem(withTitle: String($0.prefix(32))) } }
    @objc func openHistory() { let chosen = historyMenu.titleOfSelectedItem ?? ""; guard historyMenu.indexOfSelectedItem > 0 else { return }; let prefix = chosen.hasPrefix("★ ") ? String(chosen.dropFirst(2)) : chosen; if let value = (favorites + history).first(where: { $0.hasPrefix(prefix) }) { input.string = value; contentChanged() } }
    @objc func toggleFavorite() { let value = input.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines); guard !value.isEmpty else { return }; if favorites.contains(value) { favorites.removeAll { $0 == value }; status.stringValue = "Eliminado de favoritos." } else { favorites.insert(value, at: 0); status.stringValue = "Guardado en favoritos." }; UserDefaults.standard.set(favorites, forKey: "favorites"); updateHistory() }
    @objc func applyTemplate() { let values = [1:"https://ejemplo.com", 2:"WIFI:T:WPA;S:Nombre de red;P:Contraseña;;", 3:"BEGIN:VCARD\nVERSION:3.0\nFN:Nombre\nTEL:+1\nEMAIL:correo@ejemplo.com\nEND:VCARD", 4:"BEGIN:VEVENT\nSUMMARY:Evento\nDTSTART:20260101T120000\nEND:VEVENT", 5:"tel:+1", 6:"mailto:correo@ejemplo.com?subject=Asunto"]; if let value = values[templates.indexOfSelectedItem] { input.string = value; contentChanged() }; templates.selectItem(at: 0) }
    @objc func gs1Assistant() {
        let alert = NSAlert(); alert.messageText = "Asistente GS1 Digital Link"; alert.informativeText = "Crea un QR GS1 con GTIN, lote, vencimiento y número de serie."; let form = NSStackView(); form.orientation = .vertical; form.spacing = 7
        let gtin = NSTextField(string: "01234567890128"), lot = NSTextField(string: "LOTE-001"), expiry = NSTextField(string: "271231"), serial = NSTextField(string: "SERIE-001")
        [("GTIN-14",gtin),("Lote",lot),("Vencimiento YYMMDD",expiry),("Serie",serial)].forEach { title, field in let row = horizontal([label(title),field]); field.widthAnchor.constraint(equalToConstant:190).isActive = true; form.addArrangedSubview(row) }; form.frame = NSRect(x:0,y:0,width:360,height:130); alert.accessoryView = form; alert.addButton(withTitle:"Crear QR GS1"); alert.addButton(withTitle:"Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }; let digits = gtin.stringValue.compactMap { Int(String($0)) }; guard digits.count == 14, gtin.stringValue.allSatisfy(\.isNumber), checkDigit(Array(digits.dropLast())) == digits.last else { status.stringValue = "GTIN inválido: debe tener 14 dígitos y un dígito de control correcto."; return }; guard expiry.stringValue.count == 6, expiry.stringValue.allSatisfy(\.isNumber) else { status.stringValue = "La fecha debe usar el formato YYMMDD."; return }
        var url = "https://id.gs1.org/01/\(gtin.stringValue)"; if !lot.stringValue.isEmpty { url += "/10/\(lot.stringValue.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed) ?? lot.stringValue)" }; if !serial.stringValue.isEmpty { url += "/21/\(serial.stringValue.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed) ?? serial.stringValue)" }; url += "?17=\(expiry.stringValue)"; input.string = url; type.selectItem(withTitle:"Código QR"); updateType(); contentChanged(); status.stringValue = "QR GS1 Digital Link creado y validado."
    }
    func saveDraft() { let project = CodeStudioProject(content:input.string,type:type.titleOfSelectedItem ?? "PDF417",foregroundRGBA:rgba(foreground.color),backgroundRGBA:rgba(background.color),scale:scale.doubleValue,margin:margin.doubleValue,correction:correction.indexOfSelectedItem,savedAt:Date(),pdf417Aspect:aspect.doubleValue,compactPDF417:compact.state == .on); if let data = try? JSONEncoder().encode(project) { UserDefaults.standard.set(data,forKey:"automaticDraft") } }
    func restoreDraft() { guard let data = UserDefaults.standard.data(forKey:"automaticDraft"), let project = try? JSONDecoder().decode(CodeStudioProject.self,from:data) else { return }; input.string = project.content; type.selectItem(withTitle:project.type); foreground.color = color(project.foregroundRGBA); background.color = color(project.backgroundRGBA); scale.doubleValue = project.scale; margin.doubleValue = project.margin; correction.selectItem(at:max(0,min(3,project.correction))); aspect.doubleValue = project.pdf417Aspect ?? 3; compact.state = project.compactPDF417 == true ? .on : .off; count.stringValue = "\(input.string.count) caracteres"; status.stringValue = "Borrador recuperado automáticamente." }
    @objc func gradeQuality() {
        guard barcode != nil || render(input.string) != nil else { return }; func luminance(_ color:NSColor)->CGFloat { let c = color.usingColorSpace(.deviceRGB) ?? color; func channel(_ value:CGFloat)->CGFloat { value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055,2.4) }; return 0.2126*channel(c.redComponent)+0.7152*channel(c.greenComponent)+0.0722*channel(c.blueComponent) }; let a = luminance(foreground.color), b = luminance(background.color), ratio = (max(a,b)+0.05)/(min(a,b)+0.05); let module = scale.doubleValue, quiet = margin.doubleValue; let grade:String; if ratio >= 7 && module >= 4 && quiet >= 16 { grade = "A" } else if ratio >= 5 && module >= 3 && quiet >= 12 { grade = "B" } else if ratio >= 4.5 && module >= 3 && quiet >= 10 { grade = "C" } else if ratio >= 3 && module >= 2 && quiet >= 8 { grade = "D" } else { grade = "F" }; status.stringValue = "Calidad estimada: \(grade) · contraste \(String(format:"%.1f",ratio)):1 · módulo \(Int(module)) · margen \(Int(quiet))."
    }
    @objc func copyImage() { guard let image = barcode ?? render(input.string) else { return }; NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([image]); status.stringValue = "Imagen copiada al portapapeles." }
    func rgba(_ color: NSColor) -> [Double] { let value = color.usingColorSpace(.deviceRGB) ?? color; return [Double(value.redComponent), Double(value.greenComponent), Double(value.blueComponent), Double(value.alphaComponent)] }
    func color(_ values: [Double]) -> NSColor { guard values.count == 4 else { return .black }; return NSColor(red: values[0], green: values[1], blue: values[2], alpha: values[3]) }
    @objc func saveProject() {
        let project = CodeStudioProject(content: input.string, type: type.titleOfSelectedItem ?? "PDF417", foregroundRGBA: rgba(foreground.color), backgroundRGBA: rgba(background.color), scale: scale.doubleValue, margin: margin.doubleValue, correction: correction.indexOfSelectedItem, savedAt: Date(), pdf417Aspect: aspect.doubleValue, compactPDF417: compact.state == .on)
        guard let data = try? JSONEncoder().encode(project) else { return }; let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(exportedAs: "com.anthony.codestudio.project")]; panel.nameFieldStringValue = "Mi código.codestudio"
        panel.beginSheetModal(for: window!) { response in guard response == .OK, let url = panel.url else { return }; do { try data.write(to: url, options: .atomic); self.status.stringValue = "Proyecto guardado: \(url.lastPathComponent)" } catch { self.status.stringValue = "No se pudo guardar el proyecto." } }
    }
    @objc func openProject() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(exportedAs: "com.anthony.codestudio.project"), .json]; guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url), let project = try? JSONDecoder().decode(CodeStudioProject.self, from: data) else { status.stringValue = "No se pudo abrir el proyecto."; return }
        input.string = project.content; type.selectItem(withTitle: project.type); foreground.color = color(project.foregroundRGBA); background.color = color(project.backgroundRGBA); scale.doubleValue = project.scale; margin.doubleValue = project.margin; correction.selectItem(at: max(0, min(3, project.correction))); aspect.doubleValue = project.pdf417Aspect ?? 3; compact.state = project.compactPDF417 == true ? .on : .off; updateType(); contentChanged(); status.stringValue = "Proyecto abierto: \(url.lastPathComponent)"
    }
    @objc func verifyBarcode() {
        guard let image = barcode ?? render(input.string), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let cg = bitmap.cgImage else { status.stringValue = "No hay un código para verificar."; return }
        status.stringValue = "Verificando que el código pueda leerse…"; let rawExpected = input.string.trimmingCharacters(in: .whitespacesAndNewlines); let format = type.titleOfSelectedItem ?? "PDF417"; let expected: String = { let digits = rawExpected.compactMap { Int(String($0)) }; if format == "EAN-13", digits.count == 12 { return rawExpected + String(checkDigit(digits)) }; if format == "EAN-8", digits.count == 7 { return rawExpected + String(checkDigit(digits)) }; if format == "UPC-A", digits.count == 11 { return rawExpected + String(checkDigit(digits)) }; if format == "ITF-14", digits.count == 13 { return rawExpected + String(checkDigit(digits)) }; return rawExpected }()
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNDetectBarcodesRequest(); if let supported = try? request.supportedSymbologies() { request.symbologies = supported }
            do { try VNImageRequestHandler(cgImage: cg).perform([request]); let values = (request.results ?? []).compactMap(\.payloadStringValue); DispatchQueue.main.async { if values.contains(expected) { self.verifiedCount += 1; UserDefaults.standard.set(self.verifiedCount, forKey: "verifiedCount"); self.updateStatistics(); self.status.stringValue = "✓ Verificado: el código se lee correctamente." } else { self.status.stringValue = "No se pudo verificar. Aumenta el tamaño o el contraste." } } } catch { DispatchQueue.main.async { self.status.stringValue = "Error de verificación: \(error.localizedDescription)" } }
        }
    }
    @objc func scanImage() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]; panel.allowsMultipleSelection = true; guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        status.stringValue = "Analizando \(panel.urls.count) imagen(es)…"; let urls = panel.urls
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [ScanRecord] = []
            for url in urls { guard let image = NSImage(contentsOf: url), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let cg = bitmap.cgImage else { continue }; let request = VNDetectBarcodesRequest(); if let supported = try? request.supportedSymbologies() { request.symbologies = supported }; try? VNImageRequestHandler(cgImage: cg).perform([request]); for result in request.results ?? [] { if let value = result.payloadStringValue { found.append(ScanRecord(value: value, symbology: result.symbology.rawValue, date: Date())) } } }
            DispatchQueue.main.async { let existing = Set(self.scanRecords.map { "\($0.symbology)|\($0.value)" }); var seen = existing; let unique = found.filter { seen.insert("\($0.symbology)|\($0.value)").inserted }; let duplicates = found.count - unique.count; self.scanRecords.insert(contentsOf: unique, at: 0); self.scanRecords = Array(self.scanRecords.prefix(1000)); if let data = try? JSONEncoder().encode(self.scanRecords) { UserDefaults.standard.set(data, forKey: "scanRecords") }; self.showScanResults(unique); if duplicates > 0 { self.status.stringValue += " · \(duplicates) duplicado(s) ignorados." } }
        }
    }
    func showScanResults(_ latest: [ScanRecord]) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false); panel.title = "Inventario de códigos"; panel.appearance = NSAppearance(named: .darkAqua)
        let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 12; stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20); stack.translatesAutoresizingMaskIntoConstraints = false; panel.contentView?.addSubview(stack); if let content = panel.contentView { NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.topAnchor.constraint(equalTo: content.topAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)]) }
        let title = NSTextField(labelWithString: "\(latest.count) códigos detectados · \(scanRecords.count) en el historial"); title.font = .systemFont(ofSize: 22, weight: .bold); stack.addArrangedSubview(title)
        let text = NSTextView(); text.isEditable = false; text.font = .monospacedSystemFont(ofSize: 13, weight: .regular); text.string = (latest.isEmpty ? scanRecords : latest).map { "[\($0.symbology)]  \($0.value)" }.joined(separator: "\n")
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = text; stack.addArrangedSubview(scroll)
        let buttons = horizontal([makeButton("Usar primero", "arrow.down.doc", #selector(useFirstScan)), makeButton("Exportar CSV", "tablecells", #selector(exportScanHistory))]); stack.addArrangedSubview(buttons); panel.center(); panel.makeKeyAndOrderFront(nil); status.stringValue = latest.isEmpty ? "No se detectaron códigos." : "Escaneo completado: \(latest.count) códigos."
    }
    @objc func useFirstScan() { guard let first = scanRecords.first else { return }; input.string = first.value; contentChanged(); window?.makeKeyAndOrderFront(nil) }
    @objc func exportScanHistory() { let header = "fecha,formato,contenido\n"; let rows = scanRecords.map { "\($0.date.ISO8601Format()),\($0.symbology),\"\($0.value.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: "\n"); save((header + rows).data(using: .utf8), ext: "csv", type: .commaSeparatedText) }
    @objc func generateSequence() {
        let alert = NSAlert(); alert.messageText = "Crear serie consecutiva"; alert.informativeText = "Escribe un prefijo y un intervalo, por ejemplo PRODUCTO-, 1 y 100."; let accessory = NSStackView(); accessory.orientation = .vertical; accessory.spacing = 8; let prefix = NSTextField(string: "ITEM-"); let start = NSTextField(string: "1"); let end = NSTextField(string: "10"); accessory.addArrangedSubview(prefix); accessory.addArrangedSubview(start); accessory.addArrangedSubview(end); accessory.frame = NSRect(x: 0, y: 0, width: 300, height: 86); alert.accessoryView = accessory; alert.addButton(withTitle: "Crear"); alert.addButton(withTitle: "Cancelar"); guard alert.runModal() == .alertFirstButtonReturn, let first = Int(start.stringValue), let last = Int(end.stringValue), first <= last, last - first < 1000 else { return }
        let folder = NSOpenPanel(); folder.canChooseFiles = false; folder.canChooseDirectories = true; folder.prompt = "Elegir carpeta"; guard folder.runModal() == .OK, let destination = folder.url else { return }; var total = 0
        for number in first...last { let value = prefix.stringValue + String(number); guard let image = render(value), let tiff = image.tiffRepresentation, let map = NSBitmapImageRep(data: tiff), let data = map.representation(using: .png, properties: [:]) else { continue }; try? data.write(to: destination.appendingPathComponent("\(value).png")); total += 1 }; status.stringValue = "Serie completada: \(total) códigos consecutivos."
    }
    @objc func shareBarcode(_ sender: NSButton) { guard let data = bitmap(.png) else { return }; let url = FileManager.default.temporaryDirectory.appendingPathComponent("CodeStudio-codigo.png"); do { try data.write(to: url, options: .atomic); NSSharingServicePicker(items: [url]).show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY); status.stringValue = "Elige AirDrop, Mensajes, Mail u otra aplicación." } catch { status.stringValue = "No se pudo preparar el archivo para compartir." } }
    func updateStatistics() { statistics.stringValue = "\(createdCount) creados · \(verifiedCount) verificados · \(transferredCount) transferidos" }
    func bitmap(_ kind: NSBitmapImageRep.FileType, quality: CGFloat = 1) -> Data? { guard let image = barcode ?? render(input.string), let tiff = image.tiffRepresentation, let map = NSBitmapImageRep(data: tiff) else { return nil }; return map.representation(using: kind, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: quality]) }
    func save(_ data: Data?, ext: String, type: UTType) { guard let data else { return }; let panel = NSSavePanel(); panel.allowedContentTypes = [type]; panel.nameFieldStringValue = "codigo.\(ext)"; panel.beginSheetModal(for: window!) { response in guard response == .OK, let url = panel.url else { return }; do { try data.write(to: url, options: .atomic); self.status.stringValue = "Exportado: \(url.lastPathComponent)" } catch { self.status.stringValue = "Error: \(error.localizedDescription)" } } }
    @objc func exportPNG() { save(bitmap(.png), ext: "png", type: .png) }
    @objc func exportJPEG() { save(bitmap(.jpeg, quality: 0.95), ext: "jpg", type: .jpeg) }
    @objc func exportPDF() { guard let image = barcode ?? render(input.string) else { return }; let view = NSImageView(image: image); view.frame = NSRect(origin: .zero, size: image.size); save(view.dataWithPDF(inside: view.bounds), ext: "pdf", type: .pdf) }
    @objc func exportSVG() { guard let png = bitmap(.png), let image = barcode ?? render(input.string) else { return }; let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(Int(image.size.width))\" height=\"\(Int(image.size.height))\"><image width=\"100%\" height=\"100%\" href=\"data:image/png;base64,\(png.base64EncodedString())\"/></svg>"; save(svg.data(using: String.Encoding.utf8), ext: "svg", type: UTType(filenameExtension: "svg") ?? .xml) }
    @objc func printBarcode() { guard let image = barcode ?? render(input.string) else { return }; let view = NSImageView(image: image); view.imageScaling = NSImageScaling.scaleProportionallyUpOrDown; view.frame = NSRect(x: 0, y: 0, width: 612, height: 792); NSPrintOperation(view: view).run() }
    @objc func printLabels() { guard let image = barcode ?? render(input.string) else { return }; NSPrintOperation(view: LabelSheet(image)).run() }
    @objc func sendToPhone() {
        guard let png = bitmap(.png), let jpg = bitmap(.jpeg, quality: 0.95) else { status.stringValue = "Genera un código antes de enviarlo."; return }
        transferServer?.stop(); transferPanel?.close()
        let server = PhoneTransferServer(png: png, jpg: jpg); transferServer = server
        server.downloaded = { [weak self] format in guard let self else { return }; self.transferredCount += 1; UserDefaults.standard.set(self.transferredCount, forKey: "transferredCount"); self.updateStatistics(); self.status.stringValue = "El teléfono descargó el archivo \(format)." }
        status.stringValue = "Preparando transferencia privada…"
        server.start { [weak self] result in
            switch result {
            case .success(let url): self?.showTransfer(url)
            case .failure(let error): self?.status.stringValue = "No se pudo iniciar la transferencia: \(error.localizedDescription)"
            }
        }
    }
    func showTransfer(_ url: URL) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 590), styleMask: [.titled, .closable], backing: .buffered, defer: false); panel.title = "Enviar al teléfono"; panel.appearance = NSAppearance(named: .darkAqua); panel.isReleasedWhenClosed = false
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .centerX; stack.spacing = 14; stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28); stack.translatesAutoresizingMaskIntoConstraints = false; panel.contentView?.addSubview(stack)
        if let content = panel.contentView { NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.topAnchor.constraint(equalTo: content.topAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)]) }
        let title = NSTextField(labelWithString: "Escanea con la cámara del teléfono"); title.font = .systemFont(ofSize: 23, weight: .bold); stack.addArrangedSubview(title)
        let helper = NSTextField(wrappingLabelWithString: "Conecta el teléfono y la Mac a la misma red Wi‑Fi. El enlace es privado y caduca en 10 minutos."); helper.alignment = .center; helper.textColor = .secondaryLabelColor; stack.addArrangedSubview(helper)
        let filter = CIFilter(name: "CIQRCodeGenerator")!; filter.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage"); filter.setValue("M", forKey: "inputCorrectionLevel")
        if let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 9, y: 9)), let cg = ciContext.createCGImage(output, from: output.extent) { let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)); let view = NSImageView(image: image); view.imageScaling = .scaleProportionallyUpOrDown; view.wantsLayer = true; view.layer?.backgroundColor = NSColor.white.cgColor; view.layer?.cornerRadius = 18; view.heightAnchor.constraint(equalToConstant: 330).isActive = true; view.widthAnchor.constraint(equalToConstant: 330).isActive = true; stack.addArrangedSubview(view) }
        let address = NSTextField(labelWithString: url.absoluteString); address.font = .monospacedSystemFont(ofSize: 11, weight: .regular); address.textColor = .secondaryLabelColor; address.lineBreakMode = .byTruncatingMiddle; stack.addArrangedSubview(address)
        let controls = horizontal([makeButton("Copiar enlace", "link", #selector(copyTransferLink)), makeButton("Cancelar transferencia", "xmark.circle", #selector(stopTransfer))]); stack.addArrangedSubview(controls)
        transferPanel = panel; panel.center(); panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); status.stringValue = "QR listo: escanéalo desde el teléfono."
    }
    @objc func copyTransferLink() { guard let panel = transferPanel, let label = panel.contentView?.subviews.compactMap({ $0 as? NSStackView }).first?.arrangedSubviews.compactMap({ $0 as? NSTextField }).last else { return }; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(label.stringValue, forType: .string); status.stringValue = "Enlace copiado." }
    @objc func stopTransfer() { transferServer?.stop(); transferServer = nil; transferPanel?.close(); transferPanel = nil; status.stringValue = "Transferencia cancelada." }
    @objc func importCSV() { let open = NSOpenPanel(); open.allowedContentTypes = [.commaSeparatedText, .plainText]; guard open.runModal() == .OK, let url = open.url, let text = try? String(contentsOf: url, encoding: .utf8) else { return }; let lines = text.components(separatedBy: .newlines).map { $0.components(separatedBy: ",").first ?? "" }.filter { !$0.isEmpty }; let folder = NSOpenPanel(); folder.canChooseFiles = false; folder.canChooseDirectories = true; folder.prompt = "Elegir carpeta"; guard folder.runModal() == .OK, let destination = folder.url else { return }; var total = 0; for (index, value) in lines.enumerated() { guard let image = render(value), let tiff = image.tiffRepresentation, let map = NSBitmapImageRep(data: tiff), let data = map.representation(using: .png, properties: [:]) else { continue }; try? data.write(to: destination.appendingPathComponent(String(format: "codigo-%03d.png", index + 1))); total += 1 }; status.stringValue = "Lote completado: \(total) códigos."; generateBarcode() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: BarcodeWindowController?
    func applicationDidFinishLaunching(_ notification: Notification) { controller = BarcodeWindowController(); controller?.showWindow(self); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let app = NSApplication.shared, delegate = AppDelegate(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
