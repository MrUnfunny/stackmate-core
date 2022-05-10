.DEFAULT_GOAL := help
PROJECTNAME=$(shell basename "$(PWD)")
SOURCES=$(sort $(wildcard ./src/*.rs ./src/**/*.rs))
OS_NAME=$(shell uname | tr '[:upper:]' '[:lower:]')
PATH := $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/$(OS_NAME)-x86_64/bin:$(PATH)

ANDROID_AARCH64_LINKER=$(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/$(OS_NAME)-x86_64/bin/aarch64-linux-android30-clang
ANDROID_ARMV7_LINKER=$(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/$(OS_NAME)-x86_64/bin/armv7a-linux-androideabi30-clang
ANDROID_I686_LINKER=$(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/$(OS_NAME)-x86_64/bin/i686-linux-android30-clang
ANDROID_X86_64_LINKER=$(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/$(OS_NAME)-x86_64/bin/x86_64-linux-android30-clang

CC="/usr/bin/clang"
CXX="/usr/bin/clang++"

LD_LIBRARY_PATH=/usr/bin/gcc
LDFLAGS='--sysroot=$ANDROID_NDK_HOME/sysroot'
SHELL := /bin/bash

# ##############################################################################
# # GENERAL
# ##############################################################################

.PHONY: help
help: makefile
	@echo
	@echo " Available actions in "$(PROJECTNAME)":"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo

## init: Install missing dependencies.
.PHONY: init
init:
	rustup target add aarch64-apple-ios x86_64-apple-ios
	#rustup target add armv7-apple-ios armv7s-apple-ios i386-apple-ios ## deprecated
	rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
	@if [ $$(uname) == "Darwin" ] ; then cargo install cargo-lipo ; fi
	cargo install cbindgen
## :

# ##############################################################################
# # RECIPES
# ##############################################################################

## all: Compile iOS, Android and bindings targets
all: ios android bindings

## ios: Compile the iOS universal library
ios: target/universal/release/libstackmate.a

target/universal/release/libstackmate.a: $(SOURCES) ndk-home
	@if [ $$(uname) == "Darwin" ] ; then \
		cargo lipo --release ; \
		else echo "Skipping iOS compilation on $$(uname)" ; \
	fi
	@echo "[DONE] $@"

## android: Compile the android targets (arm64, armv7 and i686)
android: target/aarch64-linux-android/release/libstackmate.so target/armv7-linux-androideabi/release/libstackmate.so target/i686-linux-android/release/libstackmate.so target/x86_64-linux-android/release/libstackmate.so

target/aarch64-linux-android/release/libstackmate.so: $(SOURCES) ndk-home
	LDFLAGS=$(LDFLAGS) \
	CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=$(ANDROID_AARCH64_LINKER) \
	CC=$(CC) LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) \
	PKG_CONFIG_ALLOW_CROSS=1 OPENSSL_STATIC=1 \
		cargo build --target aarch64-linux-android --release
	@echo "[DONE] $@"

target/armv7-linux-androideabi/release/libstackmate.so: $(SOURCES) ndk-home
	LDFLAGS=$(LDFLAGS) \
	CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER=$(ANDROID_ARMV7_LINKER) \
	CC=$(CC) LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) \
	PKG_CONFIG_ALLOW_CROSS=1 OPENSSL_STATIC=1 \
		cargo build --target armv7-linux-androideabi --release
	@echo "[DONE] $@"

target/i686-linux-android/release/libstackmate.so: $(SOURCES) ndk-home
	LDFLAGS=$(LDFLAGS) \
	CARGO_TARGET_I686_LINUX_ANDROID_LINKER=$(ANDROID_I686_LINKER) \
	CC=$(CC) LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) \
	PKG_CONFIG_ALLOW_CROSS=1 OPENSSL_STATIC=1 \
		cargo  build --target i686-linux-android --release 
	@echo "[DONE] $@"

target/x86_64-linux-android/release/libstackmate.so: $(SOURCES) ndk-home
	LDFLAGS=$(LDFLAGS) \
	CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER=$(ANDROID_X86_64_LINKER) \
	CC=$(CC) LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) \
	PKG_CONFIG_ALLOW_CROSS=1 OPENSSL_STATIC=1 \
		cargo build --target x86_64-linux-android --release
	@echo "[DONE] $@"

.PHONY: ndk-home
ndk-home:
	@if [ ! -d "${ANDROID_NDK_HOME}" ] ; then \
		echo "Error: Please, set the ANDROID_NDK_HOME env variable to point to your NDK folder" ; \
		exit 1 ; \
	fi

## bindings: Generate the .h file for iOS
bindings: target/bindings.h

target/bindings.h: $(SOURCES)
	cbindgen $^ -c cbindgen.toml | grep -v \#include | uniq > $@
	@echo "[DONE] $@"

## :

# ##############################################################################
# # OTHER
# ##############################################################################

## clean:
.PHONY: clean
clean:
	cargo clean
	rm -f target/bindings.h target/bindings.src.h

## test:
.PHONY: test
test:
	cargo test