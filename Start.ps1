# Corruption of Champions Mods APK Builder
$FlashDevelop = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*|Where-Object -p "displayname" -match "flashDevelop").uninstallstring
if($FlashDevelop -eq $null){
    $FlashDevelop = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*|Where-Object -p "displayname" -match "flashDevelop").uninstallstring
}
$FlashDevelop = $FlashDevelop -replace "uninstall.exe",''
$sdk = $env:FLEX_HOME
$airNameSpace = ([xml](get-content $sdk\airsdk.xml)).airSdk.applicationNamespaces.versionMap[0].descriptorNamespace
$library = $FlashDevelop + "Library"
$fdbuild = $FlashDevelop + "Tools\fdbuild\fdbuild.exe"
$project = ".\Source\Corruption-of-Champions-FD-AIR.as3proj"

$progressPreference = 'silentlyContinue' #Hide log/verbose

#Downloads stuff and sets up directory when called
function Setup
{
	#check url for the latest release and version number if not building from source folder
	# The releases are returned in the format {"id":3622206,"tag_name":"hello-1.0.0.11",...}, we have to extract the the version number and url.
	$json = $latestRelease.Content | ConvertFrom-Json
    $Script:latestVersion = $json.tag_name[0]
	$latestUrl = $json.zipball_url[0]
	
	Write-Output "Downloading Latest Release ..."
	Invoke-WebRequest $latestUrl -OutFile coc.zip
	
	Write-Output "Extracting Archive ..."
	Expand-Archive coc.zip
	
	# just renaming and moving stuff
	if ((Test-Path ".\Source")){Remove-Item -Recurse Source}
	Move-Item coc\* Source
	Remove-Item coc,coc.zip
	
	# Edit xml to include mx swc from sdk ( otherwise gives ScrollControlBase not found error)
	$as3project = [xml](Get-Content $project)
	$as3project.project.libraryPaths.ChildNodes.Item(0).path = "lib\bin"
	$as3project.project.libraryPaths.ChildNodes.Item(1).path = $sdk+"\frameworks\libs\mx"
	$as3project.project.output.ChildNodes.Item(6).version = "27"
	$as3project.project.output.ChildNodes.Item(7).minorVersion = "0"
	$as3project.Save((Resolve-Path $project))
	
	BuildSwf
}
	
#Builds the Stuff
function BuildSwf
{
	(Get-Content $xml) -replace '<versionNumber>(.*)</versionNumber>', ('<versionNumber>'+((${latestVersion}) -split "_")[-1]+'</versionNumber>')| Set-Content $xml

	Write-Output "Compiling/Building SWF"
	&($fdbuild) ".\Source\Corruption-of-Champions-FD-AIR.as3proj" -version "4.6.0; 27.0" -compiler $sdk -notrace -library $library
	Copy-Item Source\CoC-AIR.swf CoC-AIR.swf
	
	BuildApk
}

function BuildApk
{
    $myXml = [xml](Get-Content $xml)
    $myxml.application.xmlns = $airNameSpace
    $myXml.Save((Resolve-Path $xml))

	Write-Output "Building Arm APK"
	java -jar ($sdk+"\lib\adt.jar") -package -target apk-captive-runtime -storetype pkcs12 -keystore cert.p12 -storepass coc CoC_${latestVersion}_arm.apk $xml CoC-AIR.swf icons
	
	Write-Output "Building x86 APK"
	java -jar ($sdk+"\lib\adt.jar") -package -target apk-captive-runtime -arch x86 -storetype pkcs12 -keystore cert.p12 -storepass coc CoC_${latestVersion}_x86.apk $xml CoC-AIR.swf icons
	
	exit
}

switch -wildcard (Read-Host "What would you like to do `n1.Download and Build Revamp `n2.Download and Build Xianxia `n3.Build from Source folder `n4.Build apk using CoC-AIR.swf `n5.Clean the Directory`n") 
{ 
    "1*" {
		$latestRelease = Invoke-WebRequest https://api.github.com/repos/Kitteh6660/Corruption-of-Champions-Mod/releases -Headers @{"Accept"="application/json"}
		$xml='revamp.xml'
		setup
	}
    "2*" {
		$latestRelease = Invoke-WebRequest https://api.github.com/repos/Ormael7/Corruption-of-Champions/releases -Headers @{"Accept"="application/json"}
		$xml = 'xianxia.xml'
		setup
	}
    "3*" {
		if (!(Test-Path ".\Source")){
		    Write-Output "Sorry bud missing Source Directory"
		    exit
		}
		$latestVersion = Read-Host "Enter a Version Number (eg:1.4.5):"
		$xml = Read-Host "Which XML file to use? (revamp.xml or xianxia.xml)"
		BuildSwf
	}
	"4*" {
		if (!(Test-Path ".\CoC-AIR.swf")){
		    Write-Output "Missing CoC-AIR.swf"
		    exit
		}
		$latestVersion = Read-Host "Enter a Version Number (eg:1.4.5):"
		$xml = Read-Host "Which XML file to use? (revamp.xml or xianxia.xml)"
		BuildApk
	}
	"5*" {
		Write-Output "Keeping only base files...."
		if ((Test-Path ".\Source")){Remove-Item -Recurse Source}
		if ((Test-Path "coc*")){Remove-Item -Recurse coc*}
		exit
	}
	default {
		"No idea what to do! Choose Something"
		exit
	}
}