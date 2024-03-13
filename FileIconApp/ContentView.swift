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
            Text(type)
                .bold()
            Text(name)
                .foregroundStyle(.secondary)
        }
    }
}


struct FileIconView: View {
    let url: URL

    var body: some View {
        HStack {
            if let appIcon = url.resolvedIcon {
                IconView(image: appIcon, name: url.lastPathComponent.fileName(), type: "resolvedIcon")
            }

            if let appIcon = url.customIcon {
                IconView(image: appIcon, name: url.lastPathComponent.fileName(), type: "customIcon")
            }

            if let appIcon = url.effectiveIcon {
                IconView(image: appIcon, name: url.lastPathComponent.fileName(), type: "effectiveIcon")
            }
        }
    }
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

                    Text(url.description)
                        .foregroundStyle(.secondary)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
