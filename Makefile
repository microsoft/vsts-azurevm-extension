.DEFAULT_GOAL := build

workdir := $(shell pwd)

outputPath := _build
tempLocation := _temp
tempPackagePath := $(tempLocation)/VSTSExtensionTemp
tempWindowsHandlerFilesPath := $(tempPackagePath)/ExtensionHandler/Windows
windowsHandlerArchievePackageLocation := $(outputPath)/ExtensionHandler/Windows
tempLinuxHandlerFilesPath := $(tempPackagePath)/ExtensionHandler/Linux
linuxHandlerArchievePackageLocation := $(outputPath)/ExtensionHandler/Linux

armUIPackageLocation := $(outputPath)/UI\ Package/Windows/ARM
classicUIPackageLocation := $(outputPath)/UI\ Package/Windows/Classic
armUIPackageSource := UI\ Package/Windows/ARM
classicUIPackageSource := UI\ Package/Windows/Classic

linuxarmUIPackageLocation := $(outputPath)/UI\ Package/Linux/ARM
linuxclassicUIPackageLocation := $(outputPath)/UI\ Package/Linux/Classic
linuxarmUIPackageSource := UI\ Package/Linux/ARM
linuxclassicUIPackageSource := UI\ Package/Linux/Classic


cleanExistingBuild:
	@echo "Cleaning existing build... $(outputPath)"
	@rm -rf $(outputPath)

cleanTempFolder:
	@echo "Cleaning temp folder..."
	@rm -rf $(tempLocation)

clean: cleanExistingBuild cleanTempFolder

copyLinuxHandlerDefinitionFile:
	@echo "Copying Linux handler definition file..."
	@mkdir -p $(linuxHandlerArchievePackageLocation)
	@cp ExtensionHandler/Linux/ExtensionDefinition_Test_MIGRATED.xml $(linuxHandlerArchievePackageLocation)/
	@cp ExtensionHandler/Linux/ExtensionDefinition_Prod_MIGRATED.xml $(linuxHandlerArchievePackageLocation)/

createTempLinuxHandlerPackage: copyLinuxHandlerDefinitionFile
	@echo "Creating temp Linux handler package..."
	@mkdir -p $(tempLinuxHandlerFilesPath) $(tempLinuxHandlerFilesPath)/Utils $(tempLinuxHandlerFilesPath)/Utils_python2 $(tempLinuxHandlerFilesPath)/aria
	@cp ExtensionHandler/Linux/src/**.** $(tempLinuxHandlerFilesPath)/
	@cp ExtensionHandler/Linux/src/Utils/**.** $(tempLinuxHandlerFilesPath)/Utils
	@cp ExtensionHandler/Linux/src/Utils_python2/**.** $(tempLinuxHandlerFilesPath)/Utils_python2
	@cp ExtensionHandler/Linux/src/aria/**.** $(tempLinuxHandlerFilesPath)/aria

createLinuxHandlerPackage: createTempLinuxHandlerPackage
	@echo "Creating Linux handler package..."
	@mkdir -p $(linuxHandlerArchievePackageLocation)
	@cd $(tempLinuxHandlerFilesPath) && zip -9 -r $(workdir)/$(linuxHandlerArchievePackageLocation)/RMExtension.zip *

copyWindowsHandlerDefinitionFile:
	@echo "Copying Windows handler definition file..."
	@mkdir -p $(windowsHandlerArchievePackageLocation)
	@cp ExtensionHandler/Windows/ExtensionDefinition_Test_MIGRATED.xml $(windowsHandlerArchievePackageLocation)/
	@cp ExtensionHandler/Windows/ExtensionDefinition_Prod_MIGRATED.xml $(windowsHandlerArchievePackageLocation)/

createTempWindowsHandlerPackage: copyWindowsHandlerDefinitionFile
	@echo "Creating temp Windows handler package..."
	@mkdir -p $(tempWindowsHandlerFilesPath)/src/bin/
	@cp ExtensionHandler/Windows/src/bin/* $(tempWindowsHandlerFilesPath)/src/bin/
	@cp ExtensionHandler/Windows/src/enable.cmd $(tempWindowsHandlerFilesPath)/src/
	@cp ExtensionHandler/Windows/src/disable.cmd $(tempWindowsHandlerFilesPath)/src/
	@cp ExtensionHandler/Windows/src/install.cmd $(tempWindowsHandlerFilesPath)/src/
	@cp ExtensionHandler/Windows/src/uninstall.cmd $(tempWindowsHandlerFilesPath)/src/
	@cp ExtensionHandler/Windows/src/update.cmd $(tempWindowsHandlerFilesPath)/src/
	@cp ExtensionHandler/Windows/src/HandlerManifest.json $(tempWindowsHandlerFilesPath)/src/
	@cp ExtensionHandler/Windows/src/net6.json $(tempWindowsHandlerFilesPath)/src/

createWindowsHandlerPackage: createTempWindowsHandlerPackage
	@echo "Creating Windows handler package... $(tempWindowsHandlerFilesPath)"
	@mkdir -p $(windowsHandlerArchievePackageLocation)
	@cd $(tempWindowsHandlerFilesPath)/src && zip -9 -r $(workdir)/$(windowsHandlerArchievePackageLocation)/RMExtension.zip *

generateWindowsTestArtifacts:
	@echo "Generating Windows test artifacts..."
	@pwsh CDScripts/Ev2ArtifactsGenerator.ps1 -outputDir $(windowsHandlerArchievePackageLocation)/Test -ExtensionInfoFile $(windowsHandlerArchievePackageLocation)/ExtensionDefinition_Test_MIGRATED.xml -PackageFile $(windowsHandlerArchievePackageLocation)/RMExtension.zip

generateWindowsProdArtifacts:
	@echo "Generating Windows prod artifacts..."
	@pwsh CDScripts/Ev2ArtifactsGenerator.ps1 -outputDir $(windowsHandlerArchievePackageLocation)/Prod -ExtensionInfoFile $(windowsHandlerArchievePackageLocation)/ExtensionDefinition_Prod_MIGRATED.xml -PackageFile $(windowsHandlerArchievePackageLocation)/RMExtension.zip

generateLinuxTestArtifacts:
	@echo "Generating Linux test artifacts..."
	@pwsh CDScripts/Ev2ArtifactsGenerator.ps1 -outputDir $(linuxHandlerArchievePackageLocation)/Test -ExtensionInfoFile $(linuxHandlerArchievePackageLocation)/ExtensionDefinition_Test_MIGRATED.xml -PackageFile $(linuxHandlerArchievePackageLocation)/RMExtension.zip

generateLinuxProdArtifacts:
	@echo "Generating Linux prod artifacts..."
	@pwsh CDScripts/Ev2ArtifactsGenerator.ps1 -outputDir $(linuxHandlerArchievePackageLocation)/Prod -ExtensionInfoFile $(linuxHandlerArchievePackageLocation)/ExtensionDefinition_Prod_MIGRATED.xml -PackageFile $(linuxHandlerArchievePackageLocation)/RMExtension.zip

createWindowsUIPackage:
	@echo "Creating Windows UI package..."
	@mkdir -p $(armUIPackageLocation) $(classicUIPackageLocation)
	@cd $(armUIPackageSource) && zip -9 -r $(workdir)/$(armUIPackageLocation)/UIPackage.zip *
	@cd $(classicUIPackageSource) && zip -9 -r $(workdir)/$(classicUIPackageLocation)/UIPackage.zip *

createLinuxUIPackage:
	@echo "Creating Linux UI package..."
	@mkdir -p $(linuxarmUIPackageLocation) $(linuxclassicUIPackageLocation)
	@cd $(linuxarmUIPackageSource)/ && zip -9 -r $(workdir)/$(linuxarmUIPackageLocation)/UIPackage.zip *
	@cd $(linuxclassicUIPackageSource)/ && zip -9 -r $(workdir)/$(linuxclassicUIPackageLocation)/UIPackage.zip *

build:
	@echo "Building $(outputPath)..."
	@echo "workdir = $(workdir)"
	$(MAKE) cleanExistingBuild
	$(MAKE) cleanTempFolder
	$(MAKE) createLinuxHandlerPackage
	$(MAKE) createWindowsHandlerPackage
	$(MAKE) generateWindowsTestArtifacts
	$(MAKE) generateWindowsProdArtifacts
	$(MAKE) generateLinuxTestArtifacts
	$(MAKE) generateLinuxProdArtifacts
	$(MAKE) createWindowsUIPackage
	$(MAKE) createLinuxUIPackage
	@echo "Build completed successfully."
