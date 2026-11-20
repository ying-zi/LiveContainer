//
//  LCSettingsView.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/21.
//

import Foundation
import SwiftUI
import UserNotifications

enum JITEnablerType : Int, CaseIterable, Identifiable {
    var id: Int { rawValue }
    case SideJITServer = 0
    case StikJIT = 1
    case JITStreamerEBLegacy = 2
    case StikJITLC = 3
    case SideStore = 4
    case StosDebug = 5
    case StosDebugLC = 6
    
    var displayName: String {
        switch self {
        case .StikJIT: "StikDebug"
        case .StikJITLC: "StikDebug (Another LiveContainer/Multitask)"
        case .StosDebug: "StosDebug"
        case .StosDebugLC: "StosDebug (Another LiveContainer/Multitask)"
        case .SideStore: "SideStore"
        case .JITStreamerEBLegacy: "JitStreamer-EB (Relaunch)"
        case .SideJITServer: "SideJITServer/JITStreamer 2.0"
        }
    }
}

struct LCSettingsView: View {
    @State var errorShow = false
    @State var errorInfo = ""
    @State var successShow = false
    @State var successInfo = ""

    @State private var certificateDataFound = false
    
    @StateObject private var certificateImportAlert = YesNoHelper()
    @StateObject private var certificateRemoveAlert = YesNoHelper()
    @StateObject private var certificateImportFileAlert = AlertHelper<URL>()
    @StateObject private var certificateImportPasswordAlert = InputHelper()
    
    @AppStorage("LCFrameShortcutIcons") var frameShortIcon = false
    @AppStorage("LCSwitchAppWithoutAsking") var silentSwitchApp = false
    @AppStorage("LCOpenWebPageWithoutAsking") var silentOpenWebPage = false
    @AppStorage("LCDontSignApp", store: LCUtils.appGroupUserDefault) var dontSignApp = false
    @AppStorage("LCStrictHiding", store: LCUtils.appGroupUserDefault) var strictHiding = false
    @AppStorage("dynamicColors", store: LCUtils.appGroupUserDefault) var dynamicColors = true
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) var darkModeIcon = false
    
    @AppStorage("LCSideJITServerAddress", store: LCUtils.appGroupUserDefault) var sideJITServerAddress : String = ""
    @AppStorage("LCDeviceUDID", store: LCUtils.appGroupUserDefault) var deviceUDID: String = ""
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault) var JITEnabler: JITEnablerType = .SideJITServer
    
    @State var store : Store = .Unknown
    
    @AppStorage("LCLoadTweaksToSelf") var injectToLCItelf = false
    @AppStorage("LCIgnoreJITOnLaunch") var ignoreJITOnLaunch = false
    @AppStorage("LCSelected32BitEmulator", store: LCUtils.appGroupUserDefault) var selected32BitEmulator : String = ""
    @AppStorage("LCKeepSelectedWhenQuit") var keepSelectedWhenQuit = false
    @AppStorage("LCWaitForDebugger") var waitForDebugger = false
    @AppStorage("LCSharePrivateDataWithLiveProcess") var sharePrivateDataWithLiveProcess = false
    @AppStorage("BKNoWatchdogs") var disableLiveProcessWatchdog = false
    
    @EnvironmentObject private var sharedModel : SharedModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isViewAppeared = false
    
    let storeName = LCUtils.getStoreName()
    private let dismissable: Bool
    
    init(dismissable: Bool = false) {
        self.dismissable = dismissable
        _certificateDataFound = State(initialValue: LCSharedUtils.certificatePassword() != nil)
        _store = State(initialValue: LCUtils.store())
    }
    
    private var versionFooter: some View {
        HStack(spacing: 6) {
            Text(verbatim: versionText)
                .foregroundStyle(.gray)
                .onTapGesture(count: 5) {
                    sharedModel.developerMode = true
                }
            Text(verbatim: "·")
                .foregroundStyle(.gray)
            Text(verbatim: bitInfoText)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
    }
    
    private var versionText: String {
        LCUtils.getVersionInfo()
    }
    
    private var bitInfoText: String {
        "lc.settings.selected32BitEmulator".loc + ": " + selected32BitEmulatorName
    }
    
    private var selected32BitEmulatorName: String {
        guard !selected32BitEmulator.isEmpty else {
            return "lc.common.none".loc
        }
        return sharedModel.arm32EmuApps.first {
            $0.appInfo.relativeBundlePath == selected32BitEmulator
        }?.appInfo.displayName() ?? selected32BitEmulator
    }
    
    var body: some View {
        NavigationView {
            certificateModifiers
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if dismissable {
                    Button("lc.common.close".loc) {
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear() {
            if !isViewAppeared {
                guard sharedModel.selectedTab == .settings || sharedModel.showSettings,
                      let link = sharedModel.deepLink else { return }
                sharedModel.deepLink = nil
                handleURL(url: link)
                isViewAppeared = true
            }
        }
        .onChange(of: sharedModel.deepLink) { link in
            guard sharedModel.selectedTab == .settings || sharedModel.showSettings, let link else { return }
            sharedModel.deepLink = nil
            handleURL(url: link)
        }
    }
    
    private var formWithBasicAlerts: some View {
        Form {
            settingsSections1
            settingsSections2
            settingsSections3
            settingsSections4
            settingsSections5
        }
        .navigationBarTitle("lc.tabView.settings".loc)
        .alert("lc.common.error".loc, isPresented: $errorShow){
        } message: {
            Text(errorInfo)
        }
        .alert("lc.common.success".loc, isPresented: $successShow){
        } message: {
            Text(successInfo)
        }
    }
    
    private var certificateModifiers: some View {
        formWithBasicAlerts
            .alert("lc.settings.importCertificate".loc, isPresented: $certificateImportAlert.show) {
                Button {
                    certificateImportAlert.close(result: true)
                } label: {
                    Text("lc.common.ok".loc)
                }
                
                Button("lc.common.cancel".loc, role: .cancel) {
                    certificateImportAlert.close(result: false)
                }
            } message: {
                Text("lc.settings.importCertificateDesc".loc)
            }
            .alert("lc.settings.removeCertificate".loc, isPresented: $certificateRemoveAlert.show) {
                Button(role: .destructive) {
                    certificateRemoveAlert.close(result: true)
                } label: {
                    Text("lc.common.ok".loc)
                }
                
                Button("lc.common.cancel".loc, role: .cancel) {
                    certificateRemoveAlert.close(result: false)
                }
            } message: {
                Text("lc.settings.removeCertificateDesc".loc)
            }
            .betterFileImporter(isPresented: $certificateImportFileAlert.show, types: [.p12], multiple: false, callback: { fileUrls in
                certificateImportFileAlert.close(result: fileUrls[0])
            }, onDismiss: {
                certificateImportFileAlert.close(result: nil)
            })
            .textFieldAlert(
                isPresented: $certificateImportPasswordAlert.show,
                title: "lc.settings.importCertificateInputPassword".loc,
                text: $certificateImportPasswordAlert.initVal,
                placeholder: "",
                action: { newText in
                    certificateImportPasswordAlert.close(result: newText)
                },
                actionCancel: {_ in
                    certificateImportPasswordAlert.close(result: nil)
                    certificateImportPasswordAlert.show = false
                }
            )
    }
    
    @ViewBuilder
    private var settingsSections1: some View {
        if sharedModel.multiLCStatus != 2 {
            Section{
                if !certificateDataFound {
                    Button {
                        Task{ await importCertificate() }
                    } label: {
                        Text("lc.settings.importCertificate".loc)
                    }
                } else {
                    Button {
                        Task{ await removeCertificate() }
                    } label: {
                        Text("lc.settings.removeCertificate".loc)
                    }
                }
                if store == .AltStore || store == .SideStore {
                    Button {
                        Task{ await importCertificateFromSideStore() }
                    } label: {
                        if certificateDataFound {
                            Text("lc.settings.refreshCertificateFromStore %@".localizeWithFormat(storeName))
                        } else {
                            Text("lc.settings.importCertificateFromStore %@".localizeWithFormat(storeName))
                        }
                    }
                }
                NavigationLink {
                    LCJITLessDiagnoseView()
                } label: {
                    Text("lc.settings.jitlessDiagnose".loc)
                }

            } header: {
                Text("lc.settings.jitLess".loc)
            } footer: {
                Text("lc.settings.jitLessDesc".loc)
            }
        }
        Section{
            NavigationLink {
                LCMultiLCManagementView()
            } label: {
                if sharedModel.multiLCStatus == 2 {
                    Text("lc.settings.multiLCIsSecond".loc)
                } else {
                    Text("lc.settings.multiLC".loc)
                }
            }
            .disabled(sharedModel.multiLCStatus == 2)
            
            if(sharedModel.multiLCStatus == 2) {
                NavigationLink {
                    LCJITLessDiagnoseView()
                } label: {
                    Text("lc.settings.jitlessDiagnose".loc)
                }
            }
        } footer: {
            Text("lc.settings.multiLCDesc".loc)
        }
        
        if #available(iOS 16.1, *) {
            Section {
                NavigationLink {
                    LCMultitaskSettingView()
                } label: {
                    Text("lc.appBanner.multitask".loc)
                }
            } footer: {
                Text("lc.settings.multitaskDesc".loc)
            }
        }
        
    }

    @ViewBuilder
    private var settingsSections2: some View {
        Section {
            if JITEnabler == .SideJITServer || JITEnabler == .JITStreamerEBLegacy {
                HStack {
                    Text("lc.settings.JitAddress".loc)
                    Spacer()
                    TextField(JITEnabler == .SideJITServer ? "http://x.x.x.x:8080" : "http://[fd00::]:9172", text: $sideJITServerAddress)
                        .multilineTextAlignment(.trailing)
                }
            }
            if JITEnabler == .SideJITServer {
                HStack {
                    Text("lc.settings.JitUDID".loc)
                    Spacer()
                    TextField("", text: $deviceUDID)
                        .multilineTextAlignment(.trailing)
                }
            }
            Picker(selection: $JITEnabler) {
                ForEach(JITEnablerType.allCases) { enablerType in
                    Text(enablerType.displayName).tag(enablerType)
                }
            } label: {
                Text("lc.settings.jitEnabler".loc)
            }

        } header: {
            Text("JIT")
        } footer: {
            Text("lc.settings.JitDesc".loc)
        }
        
        if !sharedModel.arm32EmuApps.isEmpty {
            Section {
                Picker(selection: $selected32BitEmulator) {
                    ForEach(sharedModel.arm32EmuApps, id: \.self) { app in
                        let appName: String = app.appInfo.displayName()
                        let appPath: String = app.appInfo.relativeBundlePath!
                        Text("lc.common.none".loc).tag("")
                        Text(appName).tag(appPath)
                    }
                } label: {
                    Text("lc.settings.selected32BitEmulator".loc)
                }
            }
        }
        
        Section{
            Toggle(isOn: $dynamicColors) {
                Text("lc.settings.dynamicColors".loc)
            }
            if #available(iOS 18.0, *) {
                Toggle(isOn: $darkModeIcon) {
                    Text("lc.settings.darkModeIcon".loc)
                }
            }
            
        } header: {
            Text("lc.settings.interface".loc)
        } footer: {
            Text("lc.settings.dynamicColors.desc".loc)
        }
    }

    @ViewBuilder
    private var settingsSections3: some View {
        Section{
            Toggle(isOn: $frameShortIcon) {
                Text("lc.settings.FrameIcon".loc)
            }
        } header: {
            Text("lc.common.miscellaneous".loc)
        } footer: {
            Text("lc.settings.FrameIconDesc".loc)
        }
        
        Section {
            Toggle(isOn: $silentSwitchApp) {
                Text("lc.settings.silentSwitchApp".loc)
            }
        } footer: {
            Text("lc.settings.silentSwitchAppDesc".loc)
        }
        
        Section {
            Toggle(isOn: $silentOpenWebPage) {
                Text("lc.settings.silentOpenWebPage".loc)
            }
        } footer: {
            Text("lc.settings.silentOpenWebPageDesc".loc)
        }
        
    }

    @ViewBuilder
    private var settingsSections4: some View {
        if sharedModel.isHiddenAppUnlocked {
            Section {
                Toggle(isOn: $strictHiding) {
                    Text("lc.settings.strictHiding".loc)
                }
            } footer: {
                Text("lc.settings.strictHidingDesc".loc)
            }
        }
        
        Section {
            Toggle(isOn: $dontSignApp) {
                Text("lc.settings.dontSign".loc)
            }
        } footer: {
            Text("lc.settings.dontSignDesc".loc)
        }

        Section {
            Button {
                clearNotifications()
            } label: {
                Text("lc.settings.clearNotifications".loc)
            }
        }

    }

    @ViewBuilder
    private var settingsSections5: some View {
        Section {
            if sharedModel.multiLCStatus != 2 {
                NavigationLink {
                    LCStorageManagementView()
                } label: {
                    Text("lc.settings.storageManagement".loc)
                }
            }
            NavigationLink {
                LCDataManagementView()
            } label: {
                Text("lc.settings.dataManagement".loc)
            }
        }
        
        versionFooter
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Color(UIColor.systemGroupedBackground))
            .listRowInsets(EdgeInsets())
        
        if sharedModel.developerMode {
            Section {
                Toggle(isOn: $injectToLCItelf) {
                    Text("lc.settings.injectLCItself".loc)
                }
                Toggle(isOn: $ignoreJITOnLaunch) {
                    Text("Ignore JIT on Launching App")
                }
                Toggle(isOn: $keepSelectedWhenQuit) {
                    Text("Keep Selected App when Quit")
                }
                Toggle(isOn: $waitForDebugger) {
                    Text("Wait For Debugger")
                }
                Toggle(isOn: $sharePrivateDataWithLiveProcess) {
                    Text("Allow Private Data access from LiveProcess")
                }
                Toggle(isOn: $disableLiveProcessWatchdog) {
                    Text("Disable LiveProcess watchdog termination")
                }
                Button {
                    export()
                } label: {
                    Text("Export Cert")
                }
                Button {
                    exportDyld()
                } label: {
                    Text("Export Dyld")
                }
                Button {
                    Task { await nukeSideStore() }
                } label: {
                    Text("Nuke SideStore")
                }
                Button {
                    exportMainBundle()
                } label: {
                    Text("Export Main Bundle")
                }
                Button {
                    resetSymbolOffsets()
                } label: {
                    Text("Reset Symbol Offsets")
                }
                Button {
                    presentFLEXOverlay()
                } label: {
                    Text("Show FLEX Overlay")
                }
                .disabled(NSClassFromString("FLEXManager") == nil)
            } header: {
                Text("Developer Settings")
            } footer: {
                Text("lc.settings.injectLCItselfDesc".loc)
            }
        }
    }

    private var navigationTitleText: String {
        return dismissable ? "lc.tabView.settings".loc : ""
    }


    func clearNotifications() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
        if #available(iOS 16.0, *) {
            notificationCenter.setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func export() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 1. Copy embedded.mobileprovision from the main bundle to Documents
        if let embeddedURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") {
            let destinationURL = documentsURL.appendingPathComponent("embedded.mobileprovision")
            do {
                try fileManager.copyItem(at: embeddedURL, to: destinationURL)
                print("Successfully copied embedded.mobileprovision to Documents.")
            } catch {
                print("Error copying embedded.mobileprovision: \(error)")
            }
        } else {
            print("embedded.mobileprovision not found in the main bundle.")
        }
        
        // 2. Read "certData" from UserDefaults and save to cert.p12 in Documents
        if let certData = LCUtils.certificateData() {
            let certFileURL = documentsURL.appendingPathComponent("cert.p12")
            do {
                try certData.write(to: certFileURL)
                print("Successfully wrote certData to cert.p12 in Documents.")
            } catch {
                print("Error writing certData to cert.p12: \(error)")
            }
        } else {
            print("certData not found in UserDefaults.")
        }
        
        // 3. Read "certPassword" from UserDefaults and save to pass.txt in Documents
        if let certPassword = LCSharedUtils.certificatePassword() {
            let passwordFileURL = documentsURL.appendingPathComponent("pass.txt")
            do {
                try certPassword.write(to: passwordFileURL, atomically: true, encoding: .utf8)
                print("Successfully wrote certPassword to pass.txt in Documents.")
            } catch {
                print("Error writing certPassword to pass.txt: \(error)")
            }
        } else {
            print("certPassword not found in UserDefaults.")
        }
    }
    
    func exportMainBundle() {
        let url = Bundle.main.bundleURL
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            try fileManager.copyItem(at: url, to: destinationURL)
            print("Successfully copied main bundle to Documents.")
        } catch {
            print("Error copying main bundle \(error)")
        }
    }
    
    func resetSymbolOffsets() {
        LCUtils.appGroupUserDefault.removeObject(forKey: "symbolOffsetCache")
    }
    
    func presentFLEXOverlay() {
        let manager = (NSClassFromString("FLEXManager") as? NSObject.Type)?.perform(NSSelectorFromString("sharedManager"))
            .takeUnretainedValue() as? NSObject
        manager?.perform(NSSelectorFromString("showExplorer"))
    }
    
    func importCertificate() async {
        guard let doImport = await certificateImportAlert.open(), doImport else {
            return
        }
        guard let certificateURL = await certificateImportFileAlert.open() else {
            return
        }
        guard let certificatePassword = await certificateImportPasswordAlert.open() else {
            return
        }
        let certificateData : Data
        do {
            certificateData = try Data(contentsOf: certificateURL)
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
            return
        }
        
        guard let _ = LCUtils.getCertTeamId(withKeyData: certificateData, password: certificatePassword) else {
            errorInfo = "lc.settings.invalidCertError".loc
            errorShow = true
            return
        }

        LCUtils.appGroupUserDefault.set(certificateData, forKey: "LCCertificateData")
        LCUtils.appGroupUserDefault.set(certificatePassword, forKey: "LCCertificatePassword")
        LCUtils.appGroupUserDefault.set(NSDate.now, forKey: "LCCertificateUpdateDate")
        certificateDataFound = true

        UserDefaults.standard.set(LCSharedUtils.appGroupID(), forKey: "LCAppGroupID")
    }
    
    func importCertificateFromSideStore() async {
        let storeScheme : String
        if store == .AltStore {
            storeScheme = "altstore-classic"
        } else {
            storeScheme = "sidestore"
        }
        
        guard let url = URL(string: "\(storeScheme.lowercased())://certificate?callback_template=livecontainer%3A%2F%2Fcertificate%3Fcert%3D%24%28BASE64_CERT%29%26password%3D%24%28PASSWORD%29") else {
            errorInfo = "Failed to initialize certificate import URL."
            errorShow = true
            return
        }
        await UIApplication.shared.open(url)
    }
    func onSideStoreCertificateCallback(certificateData: Data, password: String) {
        LCUtils.appGroupUserDefault.set(certificateData, forKey: "LCCertificateData")
        LCUtils.appGroupUserDefault.set(password, forKey: "LCCertificatePassword")
        LCUtils.appGroupUserDefault.set(NSDate.now, forKey: "LCCertificateUpdateDate")
        certificateDataFound = true
    }
    
    func removeCertificate() async {
        guard let doRemove = await certificateRemoveAlert.open(), doRemove else {
            return
        }

        LCUtils.appGroupUserDefault.set(nil, forKey: "LCCertificateData")
        LCUtils.appGroupUserDefault.set(nil, forKey: "LCCertificatePassword")
        LCUtils.appGroupUserDefault.set(nil, forKey: "LCCertificateUpdateDate")
        certificateDataFound = false

        UserDefaults.standard.set(nil, forKey: "LCAppGroupID")
    }
    
    func nukeSideStore() async {
        guard let doRemove = await certificateRemoveAlert.open(), doRemove else {
            return
        }
        do {
            let fm = FileManager.default
            let sidestoreAppGroupURL = LCPath.lcGroupDocPath.deletingLastPathComponent()
            try fm.removeItem(at: sidestoreAppGroupURL.appendingPathComponent("Database"))
            try fm.removeItem(at: sidestoreAppGroupURL.appendingPathComponent("Apps"))
        } catch {
            print("wtf \(error)")
        }
    }
    
    func exportDyld() {
        let url = URL(fileURLWithPath: "/usr/lib/dyld")
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            try fileManager.copyItem(at: url, to: destinationURL)
            print("Successfully copied dyld to Documents.")
        } catch {
            print("Error copying dyld \(error)")
        }
    }
    
    func handleURL(url: URL) {
        if url.host == "certificate" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
                guard let encodedCert = queryItems["cert"]?.removingPercentEncoding,
                      let password = queryItems["password"],
                      let certData = Data(base64Encoded: encodedCert)
                else { return }
                
                onSideStoreCertificateCallback(certificateData: certData, password: password)
                
            }
        }
    }
}
