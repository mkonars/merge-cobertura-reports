<#
.SYNOPSIS
    This script merges Cobertura reports into single file.
.DESCRIPTION
	Input parameters:
	
	-inputDirectory (mandatory) Directory where input files are placed
	
	-outputDirectory (optional) Directory where result file will be placed
	
	-outputFileName (optional) Result file name
	
	-debug (optional) When $True, additional debug values will be displayed
	
	Example usages:
	.\merge-cobertura-reports.ps1 -inputDirectory "c:\input"
	.\merge-cobertura-reports.ps1 -inputDirectory "c:\input" -outputDirectory "c:\output" -debug $True
.NOTES
    File Name  : merge-cobertura-reports.ps1
#>

Param(
	[string] $inputDirectory = "",
	[string] $outputFileName = "mergeResult.xml",
	[string] $outputDirectory = "",
	[bool] $debug = $false
)

Write-Host "Start mergeCoberturaResults script"

if(!$inputDirectory) {
	Write-Host "inputDirectory parameter is empty"
	Write-Host "Exiting"
	Exit 0
}

$files = Get-ChildItem $inputDirectory

if($files.Count -eq 0) {
	Write-Host "No files in :"$inputDirectory
	Write-Host "Exiting"
	Exit 0
}

Write-Host "Input directory: " $inputDirectory

if(!$outputDirectory) {
$outputDirectory = (Get-Item -Path ".\" -Verbose).FullName + "\"
}

Write-Host "Output directory: " $outputDirectory

$properties = "lines-covered","lines-valid","branches-covered","branches-valid","line-rate","branch-rate"
$rateProperties = "line-rate","branch-rate"
$count = 0
[xml] $mergedDocument;
$total = @{}


function GetDouble([string]$var) { [convert]::ToDouble($var.replace(".", ","))}

function CreateTotalXmlDocument($file) {

		if($debug) {
			Write-Host "Reading "$file		
		}

		[xml]$temp = Get-Content $file

		$temp.SelectNodes('/coverage/sources') | ForEach-Object {
			[void]$_.ParentNode.RemoveChild($_)
		}

		$temp.SelectNodes('/coverage/packages') | ForEach-Object {
			[void]$_.ParentNode.RemoveChild($_)
		}

		$sourcesElement = $temp.createElement("sources");
		$packagesElement = $temp.createElement("packages");
		$coverageNode = $temp.selectSingleNode("coverage")

		[void]$coverageNode.appendChild($sourcesElement);
		[void]$coverageNode.appendChild($packagesElement);
		
		if($debug) {
			Write-Host "Saving empty "$outputDirectory$outputFileName
		}
		
		$temp.Save("$outputDirectory$outputFileName") | Out-Null
		
		Get-Content $outputDirectory$outputFileName
}


[xml]$mergedDocument = CreateTotalXmlDocument($files[0].FullName)

foreach($property in $properties) {
	$total.Add($property, 0)
}
		
foreach ($fileObject in $files) {

	$file = $fileObject.FullName

	if(!$file){
		continue;
	}
	
	if($debug) {
		Write-Host "Reading Cobertura results from "$file
	}

	$count++;

	[xml]$xmlDocument = Get-Content $file
	
	$sourceNode = $mergedDocument.ImportNode($xmlDocument.SelectSingleNode("coverage/sources/source"), $true)
	$packageNode = $mergedDocument.ImportNode($xmlDocument.SelectSingleNode("coverage/packages/package"), $true)
	
	[void]$mergedDocument.selectSingleNode("coverage/sources").appendChild($sourceNode)
	[void]$mergedDocument.selectSingleNode("coverage/packages").appendChild($packageNode)

	foreach($property in $properties) {
		[string]$propertyValue = Select-Xml "/coverage/@$property" $xmlDocument
		if($debug) {
			Write-Host $Tab $property $propertyValue
		}
		
		$total[$property] += GetDouble($propertyValue)	
	}
}

$coverageNode = $mergedDocument.selectSingleNode("coverage")

foreach($property in $properties) {

	if($rateProperties -notcontains $property){
		continue;
	}

	$total[$property] = $total[$property] / $count	
}

foreach($property in $properties) {	
	if($debug) {
		Write-Host $Tab "Total $property" $total[$property]
	}
		
	$coverageNode.SetAttribute($property, $total[$property]);
}

Write-Host "Saving $outputDirectory$outputFileName"

$mergedDocument.Save("$outputDirectory$outputFileName")