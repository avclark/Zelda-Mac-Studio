#!/usr/bin/env python3
"""Generate the dependency-free Xcode app project; StudioCore is a local Swift package."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
project = root / 'ZeldaMacStudio.xcodeproj'
project.mkdir(exist_ok=True)
def uid(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
objects = []
def obj(key, text):
    objects.append(f'{uid(key)} = {{ {text} }};')
    return uid(key)
files = sorted((root / 'Sources/StudioApp').glob('*.swift'))
refs, builds = [], []
for path in files:
    key = path.name
    refs.append(obj('file'+key, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "Sources/StudioApp/{key}"; sourceTree = SOURCE_ROOT;'))
    builds.append(obj('build'+key, f'isa = PBXBuildFile; fileRef = {uid("file"+key)};'))
iconref = obj('icon', 'isa = PBXFileReference; lastKnownFileType = image.icns; path = Resources/AppIcon.icns; sourceTree = SOURCE_ROOT;')
iconbuild = obj('iconbuild', f'isa = PBXBuildFile; fileRef = {iconref};')
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = ZeldaMacStudio.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
obj('main', f'isa = PBXGroup; children = ({",".join(refs)}, {iconref}, {uid("products")},); sourceTree = "<group>";')
obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = ".";')
obj('core', f'isa = XCSwiftPackageProductDependency; package = {uid("package")}; productName = StudioCore;')
obj('corebuild', f'isa = PBXBuildFile; productRef = {uid("core")};')
obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({uid("corebuild")},); runOnlyForDeploymentPostprocessing = 0;')
obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({iconbuild},); runOnlyForDeploymentPostprocessing = 0;')
for scope in ['project', 'target']:
    for config in ['Debug','Release']:
        settings = 'MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES;'
        if scope == 'target':
            settings += ' PRODUCT_NAME = ZeldaMacStudio; PRODUCT_BUNDLE_IDENTIFIER = local.zeldamacstudio.manager; INFOPLIST_FILE = Resources/Info.plist; CODE_SIGN_STYLE = Manual; CODE_SIGN_IDENTITY = "-"; ENABLE_APP_SANDBOX = NO; COMBINE_HIDPI_IMAGES = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";'
        if config == 'Debug': settings += ' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf;'
        else: settings += ' SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
        obj(scope+config, f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {config};')
    obj(scope+'configs', f'isa = XCConfigurationList; buildConfigurations = ({uid(scope+"Debug")}, {uid(scope+"Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({uid("sources")}, {uid("frameworks")}, {uid("resources")},); buildRules = (); dependencies = (); name = ZeldaMacStudio; packageProductDependencies = ({uid("core")},); productName = ZeldaMacStudio; productReference = {product}; productType = "com.apple.product-type.application";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1620; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base,); mainGroup = {uid("main")}; packageReferences = ({uid("package")},); productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")},);')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {uid("project")}; }}\n')
schemes = project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target")}" BuildableName="ZeldaMacStudio.app" BlueprintName="ZeldaMacStudio" ReferencedContainer="container:ZeldaMacStudio.xcodeproj"/>'
(schemes/'ZeldaMacStudio.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1620" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Generated ZeldaMacStudio.xcodeproj')
