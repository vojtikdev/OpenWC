"""Regenerate the checked-in Xcode project without third-party tooling."""
from pathlib import Path
import hashlib
import json
root=Path(__file__).parent
objects={}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, value):
    key=uid(name); objects[key]=value; return key
sources=[]; files=[]
for file in sorted((root/'OpenWC').glob('*.swift')):
    ref=add('file:'+file.name, {'isa':'PBXFileReference','lastKnownFileType':'sourcecode.swift','path':file.name,'sourceTree':'<group>'})
    files.append(ref)
    sources.append(add('build:'+file.name, {'isa':'PBXBuildFile','fileRef':ref}))
plist=add('plist',{'isa':'PBXFileReference','lastKnownFileType':'text.plist.xml','path':'Info.plist','sourceTree':'<group>'})
config=add('config',{'isa':'PBXFileReference','lastKnownFileType':'text.xcconfig','path':'Config.xcconfig','sourceTree':'<group>'})
assets=add('assets',{'isa':'PBXFileReference','lastKnownFileType':'folder.assetcatalog','path':'Assets.xcassets','sourceTree':'<group>'})
assetbuild=add('assetbuild',{'isa':'PBXBuildFile','fileRef':assets})
product=add('product',{'isa':'PBXFileReference','explicitFileType':'wrapper.application','path':'OpenWC.app','sourceTree':'BUILT_PRODUCTS_DIR','includeInIndex':'0'})
sourcegroup=add('sourcegroup',{'isa':'PBXGroup','children':files+[plist,assets],'path':'OpenWC','sourceTree':'<group>'})
productgroup=add('productgroup',{'isa':'PBXGroup','children':[product],'name':'Products','sourceTree':'<group>'})
main=add('main',{'isa':'PBXGroup','children':[sourcegroup,config,productgroup],'sourceTree':'<group>'})
sourcephase=add('sourcephase',{'isa':'PBXSourcesBuildPhase','buildActionMask':'2147483647','files':sources,'runOnlyForDeploymentPostprocessing':'0'})
legalbuilds=[]
for document in sorted((root/'Legal').glob('*.md')):
    reference=add('legal:'+document.name, {'isa':'PBXFileReference','lastKnownFileType':'net.daringfireball.markdown','path':'Legal/'+document.name,'sourceTree':'<group>'})
    objects[main]['children'].append(reference)
    legalbuilds.append(add('legalbuild:'+document.name, {'isa':'PBXBuildFile','fileRef':reference}))
resourcephase=add('resourcephase',{'isa':'PBXResourcesBuildPhase','buildActionMask':'2147483647','files':[assetbuild]+legalbuilds,'runOnlyForDeploymentPostprocessing':'0'})
package=add('package',{'isa':'XCRemoteSwiftPackageReference','repositoryURL':'https://github.com/supabase/supabase-swift.git','requirement':{'kind':'exactVersion','version':'2.55.4'}})
dep=add('supabase',{'isa':'XCSwiftPackageProductDependency','package':package,'productName':'Supabase'})
depbuild=add('supabasebuild',{'isa':'PBXBuildFile','productRef':dep})
frameworkphase=add('frameworkphase',{'isa':'PBXFrameworksBuildPhase','buildActionMask':'2147483647','files':[depbuild],'runOnlyForDeploymentPostprocessing':'0'})
projectconfigs=[]; targetconfigs=[]
for mode in ['Debug','Release']:
    base={'ONLY_ACTIVE_ARCH':'YES' if mode=='Debug' else 'NO','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym'}
    projectconfigs.append(add('project'+mode,{'isa':'XCBuildConfiguration','buildSettings':base,'name':mode}))
    settings={'PRODUCT_BUNDLE_IDENTIFIER':'app.openwc.ios','PRODUCT_NAME':'$(TARGET_NAME)','INFOPLIST_FILE':'OpenWC/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'1','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','SWIFT_EMIT_LOC_STRINGS':'YES'}
    targetconfigs.append(add('target'+mode,{'isa':'XCBuildConfiguration','baseConfigurationReference':config,'buildSettings':settings,'name':mode}))
pcl=add('projectconfigs',{'isa':'XCConfigurationList','buildConfigurations':projectconfigs,'defaultConfigurationIsVisible':'0','defaultConfigurationName':'Release'})
tcl=add('targetconfigs',{'isa':'XCConfigurationList','buildConfigurations':targetconfigs,'defaultConfigurationIsVisible':'0','defaultConfigurationName':'Release'})
target=add('target',{'isa':'PBXNativeTarget','buildConfigurationList':tcl,'buildPhases':[sourcephase,frameworkphase,resourcephase],'buildRules':[],'dependencies':[],'name':'OpenWC','packageProductDependencies':[dep],'productName':'OpenWC','productReference':product,'productType':'com.apple.product-type.application'})
project=add('project',{'isa':'PBXProject','attributes':{'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2600'},'buildConfigurationList':pcl,'compatibilityVersion':'Xcode 14.0','developmentRegion':'en','hasScannedForEncodings':'0','knownRegions':['en','Base'],'mainGroup':main,'productRefGroup':productgroup,'projectDirPath':'','projectRoot':'','packageReferences':[package],'targets':[target]})
# A real iPhone UI test target exercises footer clearance, nearby search and manual pins.
testfile=add('uitestfile',{'isa':'PBXFileReference','lastKnownFileType':'sourcecode.swift','path':'OpenWCUITests.swift','sourceTree':'<group>'})
testgroup=add('uitestgroup',{'isa':'PBXGroup','children':[testfile],'path':'OpenWCUITests','sourceTree':'<group>'})
objects[main]['children'].append(testgroup)
testbuild=add('uitestbuild',{'isa':'PBXBuildFile','fileRef':testfile})
testphase=add('uitestphase',{'isa':'PBXSourcesBuildPhase','buildActionMask':'2147483647','files':[testbuild],'runOnlyForDeploymentPostprocessing':'0'})
testproduct=add('uitestproduct',{'isa':'PBXFileReference','explicitFileType':'wrapper.cfbundle','path':'OpenWCUITests.xctest','sourceTree':'BUILT_PRODUCTS_DIR','includeInIndex':'0'})
objects[productgroup]['children'].append(testproduct)
testconfigs=[]
for mode in ['Debug','Release']:
    testconfigs.append(add('uitestconfig'+mode,{'isa':'XCBuildConfiguration','name':mode,'buildSettings':{'PRODUCT_BUNDLE_IDENTIFIER':'app.openwc.uitests','PRODUCT_NAME':'$(TARGET_NAME)','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'OpenWC','CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'1'}}))
testconfiglist=add('uitestconfigs',{'isa':'XCConfigurationList','buildConfigurations':testconfigs,'defaultConfigurationIsVisible':'0','defaultConfigurationName':'Release'})
proxy=add('uitestproxy',{'isa':'PBXContainerItemProxy','containerPortal':project,'proxyType':'1','remoteGlobalIDString':target,'remoteInfo':'OpenWC'})
dependency=add('uitestdependency',{'isa':'PBXTargetDependency','target':target,'targetProxy':proxy})
testtarget=add('uitesttarget',{'isa':'PBXNativeTarget','name':'OpenWCUITests','productName':'OpenWCUITests','productReference':testproduct,'productType':'com.apple.product-type.bundle.ui-testing','buildConfigurationList':testconfiglist,'buildPhases':[testphase],'buildRules':[],'dependencies':[dependency]})
objects[project]['targets'].append(testtarget)
objects[project]['attributes']['TargetAttributes']={testtarget:{'TestTargetID':target}}

def serialize(v, depth=0):
    if isinstance(v,dict): return '{\n'+''.join('\t'*(depth+1)+json.dumps(k)+' = '+serialize(x,depth+1)+';\n' for k,x in v.items())+'\t'*depth+'}'
    if isinstance(v,list): return '(\n'+''.join('\t'*(depth+1)+serialize(x,depth+1)+',\n' for x in v)+'\t'*depth+')'
    return json.dumps(v)
p=root/'OpenWC.xcodeproj'; p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':project})+'\n')
scheme=p/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
(scheme/'OpenWC.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="OpenWC.app" BlueprintName="OpenWC" ReferencedContainer="container:OpenWC.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{testtarget}" BuildableName="OpenWCUITests.xctest" BlueprintName="OpenWCUITests" ReferencedContainer="container:OpenWC.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="OpenWC.app" BlueprintName="OpenWC" ReferencedContainer="container:OpenWC.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="OpenWC.app" BlueprintName="OpenWC" ReferencedContainer="container:OpenWC.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated OpenWC.xcodeproj')
