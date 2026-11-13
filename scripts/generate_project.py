#!/usr/bin/env python3
"""Generate the dependency-free Xcode project deterministically using stdlib."""
from pathlib import Path
import hashlib
import plistlib
import json
import re

ROOT = Path(__file__).resolve().parent.parent
identity = json.loads((ROOT / 'Config/AppIdentity.json').read_text())
bundle_id = identity.get('bundleIdentifier', '')
if set(identity) != {'bundleIdentifier'} or not isinstance(bundle_id, str) or not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle_id):
    raise SystemExit('AppIdentity.json contiene un bundleIdentifier inválido.')
project_settings = json.loads((ROOT / 'Config/ProjectSettings.json').read_text())
local_signing = ROOT / 'Config/Signing.local.json'
if local_signing.exists():
    config = json.loads(local_signing.read_text())
    team = config.get('developmentTeam', '')
    if set(config) != {'developmentTeam'} or not isinstance(team, str) or not re.fullmatch(r'[A-Z0-9]{10}', team):
        raise SystemExit('Signing.local.json debe contener solo developmentTeam con un Team ID de 10 caracteres A-Z/0-9.')
    (ROOT / 'Config/Signing.local.xcconfig').write_text(f'DEVELOPMENT_TEAM = {team}\n')



def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def quoted(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'


sources = sorted(list((ROOT / 'Sources').rglob('*.swift')) + list((ROOT / 'Support').glob('*.swift')))
objects = []


def obj(name, content):
    objects.append(f'{uid(name)} = {{ {content} }};')
    return uid(name)


files, builds = [], []
for source in sources:
    rel = str(source.relative_to(ROOT))
    files.append(obj(rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(rel)}; sourceTree = SOURCE_ROOT;'))
    builds.append(obj('build:' + rel, f'isa = PBXBuildFile; fileRef = {uid(rel)};'))
app = obj('app', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Finanzas.app; sourceTree = BUILT_PRODUCTS_DIR;')
ui_source = 'Tests/UITests/FinanceUITests.swift'
ui_file = obj(ui_source, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(ui_source)}; sourceTree = SOURCE_ROOT;')
ui_build = obj('build:ui', f'isa = PBXBuildFile; fileRef = {ui_file};')
ui_product = obj('ui:product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = FinanceUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('ui:sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({ui_build}); runOnlyForDeploymentPostprocessing = 0;')
obj('ui:frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('ui:proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target")}; remoteInfo = Finanzas;')
obj('ui:dependency', f'isa = PBXTargetDependency; target = {uid("target")}; targetProxy = {uid("ui:proxy")};')
obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
privacy_file = obj('privacy', 'isa = PBXFileReference; lastKnownFileType = text.xml; path = Config/PrivacyInfo.xcprivacy; sourceTree = SOURCE_ROOT;')
privacy_build = obj('privacy:build', f'isa = PBXBuildFile; fileRef = {privacy_file};')
icon_file = obj('assets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets/Numa.xcassets; sourceTree = SOURCE_ROOT;')
icon_build = obj('assets:build', f'isa = PBXBuildFile; fileRef = {icon_file};')
signing_file = obj('signing:config', 'isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config/Signing.xcconfig; sourceTree = SOURCE_ROOT;')
obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({privacy_build},{icon_build}); runOnlyForDeploymentPostprocessing = 0;')
obj('products', f'isa = PBXGroup; children = ({app},{ui_product},{uid("integration:product")}); name = Products; sourceTree = "<group>";')
obj('main', f'isa = PBXGroup; children = ({",".join(files)},{ui_file},{privacy_file},{icon_file},{signing_file},{uid("integration:file")},{uid("products")}); sourceTree = "<group>";')

common = '''SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 27.0; SWIFT_VERSION = 6.0;
CLANG_ENABLE_MODULES = YES; SWIFT_STRICT_CONCURRENCY = complete;
TARGETED_DEVICE_FAMILY = 1; SUPPORTS_MACCATALYST = NO;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
PRODUCT_BUNDLE_IDENTIFIER = __APP_BUNDLE__; PRODUCT_NAME = Finanzas;
INFOPLIST_FILE = Config/Info.plist; GENERATE_INFOPLIST_FILE = NO;
MARKETING_VERSION = 0.3.0; CURRENT_PROJECT_VERSION = 3;
CODE_SIGN_STYLE = Automatic; ENABLE_USER_SCRIPT_SANDBOXING = YES;
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
SWIFT_EMIT_LOC_STRINGS = YES; ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = NO;'''
common = common.replace('__APP_BUNDLE__', bundle_id)
for mode in ['Debug', 'Release']:
    optimization = 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if mode == 'Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
    optimization += ' CLANG_ENABLE_OBJC_WEAK = YES;'
    obj('target:' + mode, f'isa = XCBuildConfiguration; name = {mode}; baseConfigurationReference = {signing_file}; buildSettings = {{ {common} {optimization} }};')
    settings = ' '.join(f'{key} = {quoted(value)};' for key, value in sorted(project_settings[mode].items()))
    obj('project:' + mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ {settings} }};')
    ui_settings = '''SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 27.0; SWIFT_VERSION = 6.0;
    TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
    PRODUCT_BUNDLE_IDENTIFIER = __APP_BUNDLE__.uitests; PRODUCT_NAME = FinanceUITests;
    GENERATE_INFOPLIST_FILE = YES; TEST_TARGET_NAME = Finanzas; CODE_SIGN_STYLE = Automatic;
    SWIFT_STRICT_CONCURRENCY = complete;'''
    ui_settings = ui_settings.replace('__APP_BUNDLE__', bundle_id)
    obj('ui:' + mode, f'isa = XCBuildConfiguration; name = {mode}; baseConfigurationReference = {signing_file}; buildSettings = {{ {ui_settings} {optimization} }};')
    integration_settings = 'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 27.0; SWIFT_VERSION = 6.0; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; PRODUCT_BUNDLE_IDENTIFIER = __APP_BUNDLE__.integration; PRODUCT_NAME = FinanceIntegrationTests; GENERATE_INFOPLIST_FILE = YES; CODE_SIGN_STYLE = Automatic; SWIFT_STRICT_CONCURRENCY = complete; BUNDLE_LOADER = "$(TEST_HOST)"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Finanzas.app/Finanzas";'
    integration_settings = integration_settings.replace('__APP_BUNDLE__', bundle_id)
    obj('integration:' + mode, f'isa = XCBuildConfiguration; name = {mode}; baseConfigurationReference = {signing_file}; buildSettings = {{ {integration_settings} {optimization} }};')
for owner in ['target', 'project', 'ui', 'integration']:
    obj(owner + ':configs', f'isa = XCConfigurationList; buildConfigurations = ({uid(owner + ":Debug")},{uid(owner + ":Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target', f'''isa = PBXNativeTarget; buildConfigurationList = {uid("target:configs")};
buildPhases = ({uid("sources")},{uid("frameworks")},{uid("resources")}); buildRules = (); dependencies = ();
name = Finanzas; productName = Finanzas; productReference = {app}; productType = "com.apple.product-type.application";''')
obj('ui:target', f'''isa = PBXNativeTarget; buildConfigurationList = {uid("ui:configs")};
buildPhases = ({uid("ui:sources")},{uid("ui:frameworks")}); buildRules = (); dependencies = ({uid("ui:dependency")});
name = FinanceUITests; productName = FinanceUITests; productReference = {ui_product}; productType = "com.apple.product-type.bundle.ui-testing";''')
integration_file = obj('integration:file', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tests/IntegrationTests/StorageTests.swift; sourceTree = SOURCE_ROOT;')
integration_build = obj('integration:build', f'isa = PBXBuildFile; fileRef = {integration_file};')
obj('integration:sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({integration_build}); runOnlyForDeploymentPostprocessing = 0;')
obj('integration:frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('integration:product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = FinanceIntegrationTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('integration:target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("integration:configs")}; buildPhases = ({uid("integration:sources")},{uid("integration:frameworks")}); buildRules = (); dependencies = ({uid("ui:dependency")}); name = FinanceIntegrationTests; productName = FinanceIntegrationTests; productReference = {uid("integration:product")}; productType = "com.apple.product-type.bundle.unit-test";')
obj('project', f'''isa = PBXProject; attributes = {{ LastUpgradeCheck = 2710; BuildIndependentTargetsInParallel = YES; }};
buildConfigurationList = {uid("project:configs")}; compatibilityVersion = "Xcode 14.0";
developmentRegion = es; knownRegions = (es, Base); mainGroup = {uid("main")}; productRefGroup = {uid("products")};
projectDirPath = ""; projectRoot = ""; hasScannedForEncodings = 0; targets = ({uid("target")},{uid("ui:target")},{uid("integration:target")});''')
project = ROOT / 'Finanzas.xcodeproj'
project.mkdir(exist_ok=True)
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + '\n}; rootObject = ' + uid('project') + '; }\n')
schemes = project / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
(schemes / 'Finanzas.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="Finanzas.app" BlueprintName="Finanzas" ReferencedContainer="container:Finanzas.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO"><CommandLineArguments><CommandLineArgument argument="--ui-testing" isEnabled="YES"/></CommandLineArguments><EnvironmentVariables><EnvironmentVariable key="FINANCE_TEST_STORE" value="A1563210-1111-4222-8333-444455556666" isEnabled="YES"/></EnvironmentVariables><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('ui:target')}" BuildableName="FinanceUITests.xctest" BlueprintName="FinanceUITests" ReferencedContainer="container:Finanzas.xcodeproj"/></TestableReference><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('integration:target')}" BuildableName="FinanceIntegrationTests.xctest" BlueprintName="FinanceIntegrationTests" ReferencedContainer="container:Finanzas.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="Finanzas.app" BlueprintName="Finanzas" ReferencedContainer="container:Finanzas.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
config = ROOT / 'Config'
config.mkdir(exist_ok=True)
info = {
    'CFBundleDevelopmentRegion': 'es', 'CFBundleDisplayName': 'Numa',
    'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
    'CFBundleInfoDictionaryVersion': '6.0', 'CFBundleName': 'Numa',
    'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '$(MARKETING_VERSION)',
    'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)', 'LSRequiresIPhoneOS': True,
    'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False},
    'UILaunchScreen': {}, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
    'ITSAppUsesNonExemptEncryption': False,
}
(config / 'Info.plist').write_bytes(plistlib.dumps(info, sort_keys=True))
print(f'Generated {project.name} with {len(sources)} Swift sources.')
