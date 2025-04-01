//
//  ContentView.swift
//  FileIconApp
//
//  Created by Stef Kors on 12/03/2024.
//

import SwiftUI
import UniformTypeIdentifiers

extension URL {
    var effectiveIcon: NSImage? {
        try? self.resourceValues(forKeys: [.effectiveIconKey]).effectiveIcon as? NSImage
    }

    var customIcon: NSImage? {
        try? self.resourceValues(forKeys: [.customIconKey]).customIcon
    }

    var resolvedIcon: NSImage? {
        self.customIcon ?? self.effectiveIcon
    }

    var contentAccessDate: Date? {
        try? self.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
    }
}

extension String {

    func fileName() -> String {
        return URL(fileURLWithPath: self).deletingPathExtension().lastPathComponent
    }

    func fileExtension() -> String {
        return URL(fileURLWithPath: self).pathExtension
    }
}

struct IconView: View {
    let image: NSImage
    let name: String
    let type: String

    private var imageUrl: URL {
        let temp = FileManager.default.temporaryDirectory
        let fileUrl = temp.appending(component: name + "-" + type + ".png")
        savePNG(image: image, path: fileUrl)
        return fileUrl
    }

    private func savePNG(image: NSImage, path: URL) {
        let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)
        let pngData = imageRep?.representation(using: .png, properties: [:])
        do {
            try pngData!.write(to: path)

        } catch {
            print(error)
        }
    }

    var body: some View {
        VStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .draggable(imageUrl)

            Text(name)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    print(FileManager.default.urls(for: .downloadsDirectory, in: .allDomainsMask))

                    let destinationURL = URL.downloadsDirectory.appendingPathComponent(imageUrl.lastPathComponent)
                    do {
                        let exists = FileManager.default.fileExists(atPath: imageUrl.path())
                        if exists {
                            
                            print("file exists: trying to copy")
                            try FileManager.default.copyItem(at: imageUrl, to: destinationURL)
                        } else {
                            print("file doesn't exists")
                        }
                    } catch {
                        print("Error saving image: \(error)")
                    }
                    NSWorkspace.shared.recycle([URL.downloadsDirectory])

                } label: {
                    Label("Save Image", systemImage: "arrow.down.circle.fill")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity).animation(.snappy.delay(0.1)))
                .buttonStyle(.borderedProminent)

                Button {
                    NSWorkspace.shared.open(imageUrl)
                } label: {
                    Label("Open File", systemImage: "arrow.up.forward.circle.fill")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity).animation(.snappy.delay(0.1)))
                .labelStyle(.iconOnly)
            }
        }
        .task(id: name) {
            let temp = FileManager.default.temporaryDirectory
            let fileUrl = temp.appending(component: name + "-" + type + ".png")
            savePNG(image: image, path: fileUrl)
        }
        .contextMenu {
            Button("Copy URL") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(imageUrl.absoluteString, forType: .string)
            }

            Button("Copy File") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([imageUrl as NSURL])
            }

            Button("Open File") {
                NSWorkspace.shared.open(imageUrl)
            }

            Divider()

            Button("Save Image to Downloads") {
                if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                    let destinationURL = downloadsURL.appendingPathComponent(imageUrl.lastPathComponent)
                    if let imageData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: imageData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: destinationURL)
                        NSWorkspace.shared.recycle([downloadsURL])
                    }
                }
            }

            Button("Save as..") {
                let savePanel = NSSavePanel()
                savePanel.title = "Save Image"
                savePanel.nameFieldStringValue = imageUrl.lastPathComponent
                savePanel.begin { response in
                    if response == .OK, let destinationURL = savePanel.url {
                        do {
                            try FileManager.default.copyItem(at: imageUrl, to: destinationURL)
                        } catch {
                            print("Error saving image: \(error)")
                        }
                    }
                }
            }

            Divider()

            Button("Share File") {
                let picker = NSSharingServicePicker(items: [imageUrl])
                if let window = NSApplication.shared.keyWindow, let contentView = window.contentView {
                    picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                }
            }
        }
    }
}


struct FileIconView: View {
    let url: URL

    var body: some View {
        HStack {
            if let appIcon = url.resolvedIcon {
                IconView(image: appIcon, name: url.lastPathComponent.fileName(), type: "resolvedIcon")
            } else if let appIcon = url.customIcon {
                IconView(image: appIcon, name: url.lastPathComponent.fileName(), type: "customIcon")
            } else if let appIcon = url.effectiveIcon {
                IconView(image: appIcon, name: url.lastPathComponent.fileName(), type: "effectiveIcon")
            }
        }
    }
}


#Preview {
    FileIconView(url: URL(string: "file:/System/Applications/Facetime.app")!)
        .scenePadding()
}

struct ContentView: View {
    @State private var url: URL?
    @State private var isDropTargeted: Bool = false
    var body: some View {
        ZStack {
            if isDropTargeted {
                RadialGradient(colors: [.clear, Color.accentColor], center: .center, startRadius: 200, endRadius: 0)
                    .transition(.scale.combined(with: .opacity))
            }

            VStack(spacing: 20) {
                if let url {
                    FileIconView(url: url)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .navigationSubtitle(url.lastPathComponent)
                } else {
                    GroupBox {
                        VStack {
                            Text("drop file here to get file icon")
                        }.frame(width: 300, height: 300)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .toolbar(content: {
            ToolbarItem {
                Button("Clear") {
                    url = nil
                }
                .disabled(url == nil)
            }
        })
        .animation(.snappy, value: url)
        .animation(.snappy, value: isDropTargeted)
        .onDrop(of: [.url], isTargeted: $isDropTargeted, perform: { providers in
            var success = false
            providers.forEach { item in
                let _ = item.loadObject(ofClass: URL.self) { (data, error) in
                    if let data {
                        self.url = data
                        success = true
                    }
                }
            }
            return success
        })
        .padding()
    }
}

#Preview {
    ContentView()
}
