# swk kernel: standalone tests. Use `mingw32-make` on Windows, `make` elsewhere.
#   make test        build into build/ and run the tests
#   make clean       remove build/

CXX      ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -pedantic -isystem ../include -Iinclude
LDFLAGS  ?=

ifeq ($(OS),Windows_NT)
  # Static so the test exe runs without the MinGW runtime DLLs next to it.
  LDFLAGS += -static
  EXE := .exe
else
  EXE :=
endif

BUILD := build
TEST  := $(BUILD)/swk_tests$(EXE)
HDRS  := $(wildcard include/swk/*.hpp)
SRCS  := tests/swk_tests.cpp tests/swk_second_tu.cpp

.PHONY: test clean

test: $(TEST)
	./$(TEST)

$(TEST): $(SRCS) $(HDRS) | $(BUILD)
	$(CXX) $(CXXFLAGS) $(SRCS) -o $@ $(LDFLAGS)

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)

# --- C interface: shared library for ctypes (and anything else) ---
ifeq ($(OS),Windows_NT)
  CAPI_LIB := $(BUILD)/swk.dll
  CAPI_LDFLAGS := -shared -static -static-libgcc -static-libstdc++
else ifeq ($(shell uname -s),Darwin)
  CAPI_LIB := $(BUILD)/libswk.dylib
  CAPI_LDFLAGS := -dynamiclib
else
  CAPI_LIB := $(BUILD)/libswk.so
  CAPI_LDFLAGS := -shared
endif
CAPI_CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -pedantic -fPIC -fvisibility=hidden -isystem ../include -Iinclude -Icapi

.PHONY: capi
capi: $(CAPI_LIB)

$(CAPI_LIB): capi/swk_c.cpp capi/swk_c.h $(HDRS) | $(BUILD)
	$(CXX) $(CAPI_CXXFLAGS) capi/swk_c.cpp -o $@ $(CAPI_LDFLAGS)
