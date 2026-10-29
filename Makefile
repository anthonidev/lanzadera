# Comandos habituales de Lanzadera. Requiere Xcode 27, xcodegen y swiftlint (brew install xcodegen swiftlint).

DERIVED := build
APP_DEBUG := $(DERIVED)/Build/Products/Debug/Lanzadera.app
APP_RELEASE := $(DERIVED)/Build/Products/Release/Lanzadera.app

.PHONY: project build run test lint format install clean

project:  ## Genera Lanzadera.xcodeproj a partir de project.yml
	xcodegen generate --quiet

build: project  ## Compila en Debug
	xcodebuild -project Lanzadera.xcodeproj -scheme Lanzadera -configuration Debug \
		-derivedDataPath $(DERIVED) -allowProvisioningUpdates build -quiet

run: build  ## Compila y abre la app (cierra la instancia anterior)
	-pkill -x Lanzadera && sleep 1
	open $(APP_DEBUG)

test:  ## Pruebas del paquete LanzaderaKit
	cd Packages/LanzaderaKit && swift test

lint:  ## SwiftLint sobre todo el código
	swiftlint lint --quiet --strict

format:  ## Formatea con swift-format (incluido en Xcode)
	xcrun swift-format format --in-place --recursive App/Sources Packages/LanzaderaKit/Sources Packages/LanzaderaKit/Tests

install: project  ## Compila en Release e instala en /Applications
	xcodebuild -project Lanzadera.xcodeproj -scheme Lanzadera -configuration Release \
		-derivedDataPath $(DERIVED) -allowProvisioningUpdates build -quiet
	-pkill -x Lanzadera && sleep 1
	rm -rf /Applications/Lanzadera.app
	cp -R $(APP_RELEASE) /Applications/Lanzadera.app
	open /Applications/Lanzadera.app

clean:
	rm -rf $(DERIVED) Lanzadera.xcodeproj Packages/LanzaderaKit/.build
