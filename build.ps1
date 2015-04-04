Framework "4.0"

###################### Properties ##############################################################

properties {
	$project_name = "TeamcityTestSite"
	$company_name = "Steven D'Anna"
	$base_dir = resolve-path .
	
	$build_dir = "$base_dir\build"
	$test_dir = "$build_dir\test"
	$test_copy_ignore_path = "_ReSharper"
	$tools_path = "$base_dir\tools"
	$packages_path = "$base_dir\src\packages"
	#$7zip_path = "$tools_path\7zip\7za.exe"
	#$nuget_path = "$tools_path\nuget\nuget.exe"
	$xunit_path = "$packages_path\xunit.runner.console.2.0.0\tools\xunit.console.exe"
	$unit_test_source_dir = "$base_dir\src\UnitTests\bin\$project_config"
	$unit_test_dll = "$test_dir\UnitTests.dll"
	$integration_test_source_dir = "$base_dir\src\IntegrationTests\bin\$project_config"
	#$integration_test_dll = "$test_dir\IntegrationTests.dll"
	#$integration_test_config = "$test_dir\IntegrationTests.dll.config"
	$source_dir = "$base_dir\src"	
	#$ftp_base_dir = "\\files.praeses.com\FileTransfers\Projects\HII-Labor Collection"
	#$ftp_dir = "$ftp_base_dir\$project_config"
	#$now = [System.DateTime]::Now
	#$now_year = $now.Year
	#$now_version_1 = $now_year
	#$now_version_2 = $now.ToString("MMdd")
	#$now_version_3 = $now.ToString("HHmm")
	#$version = "$now_version_1.$now_version_2.$now_version_3"
	$iis_deploy_username = "$project_name-Deploy"
	$iis_deploy_password = "TBD"
}

##################### Tasks ####################################################################

#task default -depends Init, CommonAssemblyInfo, Compile, UnitTest, IntegrationTest
task default -depends Init, Compile, UnitTest, IntegrationTest

task Init {	
	msbuild /t:clean /v:q /nologo /p:configuration=$project_config $source_dir\$project_name.sln
	delete_directory $build_dir
	create_directory $build_dir
	create_directory $test_dir
}

#task CommonAssemblyInfo -depends Init {  
#    create-commonAssemblyInfo "$version" $projectName "$source_dir\CommonAssemblyInfo.cs"
#}

#task Compile -depends CommonAssemblyInfo {	
task Compile -depends Init {	
	#exec {
	#	& $nuget_path restore $source_dir\$project_name.sln
	#}
	Write-Host "Compiling version: $version"
	msbuild /t:build /v:q /nologo /p:configuration=$project_config $source_dir\$project_name.sln
}

task UnitTest -depends Compile {
	copy_all_assemblies_for_test $unit_test_source_dir $test_dir
	exec {
		& $xunit_path $unit_test_dll -nunit results-unit.xml
	}
}

#task IntegrationTest -depends Compile {
#	copy_all_assemblies_for_test $integration_test_source_dir $test_dir
#	ensure_db_is_migrated $integration_test_config	
#	exec {
#		& $xunit_path $integration_test_dll /nunit results-integration.xml
#	}
#}

task Publish -depends Compile { 
	Remove-Item $build_dir -Recurse -Force -ErrorAction SilentlyContinue  #Cleanup the build directory
	exec { 
		#PortersCleaners-Deploy is an IIS Manager User
		msbuild $source_dir\$project_name.sln /property:DeployOnBuild=true /property:PublishProfile=$project_config /property:UserName=$iis_deploy_username /property:Password=$iis_deploy_username /property:AllowUntrustedCertificate=true /v:q /nologo /clp:ErrorsOnly 
	}
}

task Package-Service -depends Publish {
	$bin = "$source_dir\WindowsService\bin\$project_config"
	$dest = "$build_dir\Service"
	$exclude = @('*.xml','*.pdb') 
	copy_files $bin $dest $exclude
}

task Package -depends Publish, Package-Service {
	# Create a Package-* function for each thing that needs to be deployed.
	# For instance if we had a service project and a web project you would 
	# have 2 functions:
	#	Package-Website
	#	Package-Service
	# These functions should put the deployables into the appropriate folders
	# underneath the <root>/Build folder.  Given the scenario above, you would
	# have the following folder structure
	# <source root>
	#     |--- Build
	#			 |--- Web
	#			 |--- Service
	# This will allow the FTP task to come in an easily grab everything, zip it 
	# up and push it to the FTP so that the customer can grab it.
	#
	#Package-Website - Done by the Publish task on External-* builds
}

# Zips up the contents of the build folder and pushes to the HII FTP site we have set up.
#task FTP -depends Package {
#	$zipFileName = "$build_dir\LC-$project_config-$version.zip"
#	$zipFileFullName = [IO.Path]::GetFullPath($zipFileName);
#	Write-Host Zipping up build contents into $zipFileFullName
#	exec {		
#		& $7zip_path a $zipFileFullName -tzip $build_dir\*
#	}
#	Copy-Item $zipFileFullName $ftp_dir -Force
#}



##################### Functions ###################################################


function global:copy_website_files($source,$destination){
    $exclude = @('*.user','*.dtd','*.tt','*.cs','*.csproj','*.orig', '*.log') 
    copy_files $source $destination $exclude
	delete_directory "$destination\obj"
}

function global:copy_files($source,$destination,$exclude=@()){    
    create_directory $destination
    Get-ChildItem $source -Recurse -Exclude $exclude | Copy-Item -Destination {Join-Path $destination $_.FullName.Substring($source.length)} -ErrorVariable capturedErrors -ErrorAction SilentlyContinue
	$capturedErrors | foreach-object { if ($_ -notmatch "already exists") { write-error $_ } }
}

function global:delete_directory($directory_name)
{
	rd $directory_name -recurse -force  -ErrorAction SilentlyContinue | out-null
}

function global:create_directory($directory_name)
{
	mkdir $directory_name  -ErrorAction SilentlyContinue  | out-null
}

function global:Copy_and_flatten ($source,$filter,$dest) {
	ls $source -filter $filter  -r | Where-Object{!$_.FullName.Contains("$test_copy_ignore_path") -and !$_.FullName.Contains("packages") }| cp -dest $dest -force
}

function global:copy_all_assemblies_for_test($source,$destination){
	delete_directory $destination
	create_directory $destination
	Copy_and_flatten $source *.exe $destination
	Copy_and_flatten $source *.dll $destination
	Copy_and_flatten $source *.config $destination
	Copy_and_flatten $source *.xml $destination
	Copy_and_flatten $source *.pdb $destination
	Copy_and_flatten $source *.sql $destination
	Copy_and_flatten $source *.xlsx $destination
}

function global:set_config_file($config_path){
	[System.AppDomain]::CurrentDomain.SetData("APP_CONFIG_FILE", $config_path)
}

function global:create-commonAssemblyInfo($version,$applicationName,$filename)
{
"using System;
using System.Reflection;
using System.Runtime.InteropServices;

//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated by a tool.
//     Runtime Version:2.0.50727.4927
//
//     Changes to this file may cause incorrect behavior and will be lost if
//     the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

[assembly: ComVisibleAttribute(false)]
[assembly: AssemblyVersionAttribute(""$version"")]
[assembly: AssemblyFileVersionAttribute(""$version"")]
[assembly: AssemblyCopyrightAttribute(""Copyright $now_year"")]
[assembly: AssemblyProductAttribute(""$applicationName"")]
[assembly: AssemblyCompanyAttribute(""$company_name"")]
[assembly: AssemblyConfigurationAttribute(""release"")]
[assembly: AssemblyInformationalVersionAttribute(""$version"")]"  | out-file $filename -encoding "ASCII"    
}